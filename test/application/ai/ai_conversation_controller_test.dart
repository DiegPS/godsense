import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/ai/ai_conversation_controller.dart';
import 'package:godsense/application/ai/ai_runtime_services.dart';
import 'package:godsense/application/ai/ai_runtime_supervisor.dart';
import 'package:godsense/domain/ai/ai_runtime_api_models.dart';
import 'package:godsense/domain/ai/ai_runtime_models.dart';

class MockAiRuntimeClient implements AiRuntimeClient {
  final _eventController = StreamController<AiRuntimeEvent>.broadcast();
  final List<String> promptsSent = [];
  final List<String> abortedSessions = [];
  List<Map<String, dynamic>> mockMessages = [];
  bool throwOnPrompt = false;
  bool throwOnAbort = false;
  int disposedCount = 0;

  Completer<void>? connectEventsDelay;

  void emitEvent(AiRuntimeEvent event) => _eventController.add(event);

  @override
  Stream<AiRuntimeEvent> events() => _eventController.stream;

  @override
  Future<Stream<AiRuntimeEvent>> connectEvents() async {
    if (connectEventsDelay != null) {
      await connectEventsDelay!.future;
    }
    return _eventController.stream;
  }

  @override
  Future<AiSession> createSession({String? title}) async =>
      const AiSession(id: 'mock-session-1');

  @override
  Future<void> promptAsync(String sessionId, AiPrompt prompt) async {
    if (throwOnPrompt) throw StateError('Connection failed');
    promptsSent.add(prompt.text);
  }

  @override
  Future<void> abort(String sessionId) async {
    if (throwOnAbort) throw StateError('Abort failed on server');
    abortedSessions.add(sessionId);
  }

  @override
  Future<List<Map<String, dynamic>>> messages(String sessionId) async =>
      mockMessages;

  @override
  Future<void> deleteSession(String sessionId) async {}

  @override
  Future<List<AiProviderInfo>> providers() async => const [];

  @override
  Future<List<AiAuthMethod>> authMethods() async => const [];

  @override
  Future<AiSession> session(String sessionId) async =>
      const AiSession(id: 'mock-session-1');

  @override
  void dispose() {
    disposedCount++;
    _eventController.close();
  }
}

class FakeSupervisor implements AiRuntimeSupervisor {
  FakeSupervisor({this.ready = true, this.port = 5555});

  bool ready;
  int port;

  @override
  AiRuntimeSupervisorState get state => AiRuntimeSupervisorState(
    lifecycle: ready ? AiRuntimeLifecycle.ready : AiRuntimeLifecycle.stopped,
    kind: AiRuntimeKind.kilo,
    endpoint: ready
        ? AiRuntimeEndpoint(
            kind: AiRuntimeKind.kilo,
            baseUri: Uri.parse('http://127.0.0.1:$port'),
            username: 'kilo',
            password: 'pwd-$port',
            pid: 1000 + port,
          )
        : null,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockAiRuntimeClient mockClient;

  setUp(() {
    mockClient = MockAiRuntimeClient();
  });

  tearDown(() {
    mockClient.dispose();
  });

  test('refuses to send if supervisor is not ready', () async {
    final controller = AiConversationController(
      supervisor: FakeSupervisor(ready: false),
      clientFactory: () => mockClient,
    );

    await controller.sendMessage('Hola');
    expect(controller.state.status, AiConversationStatus.error);
    expect(controller.state.errorMessage, contains('no está encendido'));
    expect(controller.state.messages, isEmpty);
  });

  test('streams text deltas and commits message on completion', () async {
    final controller = AiConversationController(
      supervisor: FakeSupervisor(ready: true),
      clientFactory: () => mockClient,
    );

    final sendFuture = controller.sendMessage('¿Qué compro con Ahri?');
    await pumpEventQueue();

    expect(controller.state.status, AiConversationStatus.streaming);
    expect(mockClient.promptsSent, contains('¿Qué compro con Ahri?'));
    expect(controller.state.messages.length, 1);
    expect(controller.state.messages.first.role, 'user');

    // Emit text deltas via SSE
    mockClient.emitEvent(
      const AiRuntimeEvent(
        type: 'message.part.delta',
        properties: {'delta': 'Compra '},
        raw: {},
      ),
    );
    await pumpEventQueue();
    expect(controller.state.streamedText, 'Compra ');

    mockClient.emitEvent(
      const AiRuntimeEvent(
        type: 'message.part.delta',
        properties: {'delta': 'Luden.'},
        raw: {},
      ),
    );
    await pumpEventQueue();
    expect(controller.state.streamedText, 'Compra Luden.');

    // Emit completion event
    mockClient.emitEvent(
      const AiRuntimeEvent(
        type: 'message.completed',
        properties: {},
        raw: {},
      ),
    );
    await pumpEventQueue();

    expect(controller.state.status, AiConversationStatus.idle);
    expect(controller.state.streamedText, isEmpty);
    expect(controller.state.messages.length, 2);
    expect(controller.state.messages.last.role, 'assistant');
    expect(controller.state.messages.last.content, 'Compra Luden.');

    await sendFuture;
  });

  test('streaming distinguishes incremental delta from fullPartText without duplicating', () async {
    final controller = AiConversationController(
      supervisor: FakeSupervisor(ready: true),
      clientFactory: () => mockClient,
    );

    final send = controller.sendMessage('Prueba de deduplicación');
    await pumpEventQueue();

    // 1. Emit incremental delta
    mockClient.emitEvent(
      const AiRuntimeEvent(
        type: 'message.part.delta',
        properties: {'delta': 'Hola'},
        raw: {},
      ),
    );
    await pumpEventQueue();
    expect(controller.state.streamedText, 'Hola');

    // 2. Kilo emits message.part.updated with the full consolidated part text
    mockClient.emitEvent(
      const AiRuntimeEvent(
        type: 'message.part.updated',
        properties: {
          'part': {'type': 'text', 'text': 'Hola mundo'},
        },
        raw: {},
      ),
    );
    await pumpEventQueue();

    // Must NOT be "HolaHola mundo"; must be replaced by "Hola mundo"
    expect(controller.state.streamedText, 'Hola mundo');

    await controller.abort();
    await send;
  });

  test('consecutive question does not pick up previous completed assistant answer during polling', () async {
    final controller = AiConversationController(
      supervisor: FakeSupervisor(ready: true),
      clientFactory: () => mockClient,
    );

    // Mock history already has Question 1 and Answer 1
    mockClient.mockMessages = [
      {
        'info': {'role': 'user'},
        'parts': [
          {'type': 'text', 'text': 'Pregunta previa 1'},
        ],
      },
      {
        'info': {'role': 'assistant', 'finish': 'stop'},
        'parts': [
          {'type': 'text', 'text': 'Respuesta vieja 1'},
        ],
      },
      {
        'info': {'role': 'user'},
        'parts': [
          {'type': 'text', 'text': 'Pregunta nueva 2'},
        ],
      },
      // Notice: No assistant answer yet for Question 2!
    ];

    final send = controller.sendMessage('Pregunta nueva 2');
    await pumpEventQueue();

    // Give reconciliation polling loop a chance to run
    await Future<void>.delayed(const Duration(milliseconds: 700));

    // Must NOT be completed with 'Respuesta vieja 1'
    expect(controller.state.status, AiConversationStatus.streaming);
    expect(controller.state.streamedText, isEmpty);

    // Now emit the true answer for Question 2
    mockClient.emitEvent(
      const AiRuntimeEvent(
        type: 'message.part.delta',
        properties: {'delta': 'Respuesta fresca 2'},
        raw: {},
      ),
    );
    await pumpEventQueue();
    expect(controller.state.streamedText, 'Respuesta fresca 2');

    await controller.abort();
    await send;
  });

  test('restarting Kilo recreates client and resets session', () async {
    final supervisor = FakeSupervisor(ready: true, port: 5001);
    var clientCount = 0;
    final controller = AiConversationController(
      supervisor: supervisor,
      clientFactory: () {
        clientCount++;
        return mockClient;
      },
    );

    await controller.sendMessage('Pregunta con primer proceso');
    expect(controller.state.sessionId, 'mock-session-1');
    expect(clientCount, 1);
    await controller.abort();

    // Simulate Kilo stopping and restarting on a new port
    supervisor.port = 5002;

    await controller.sendMessage('Pregunta con nuevo proceso Kilo');
    // Client should have been recreated
    expect(clientCount, 2);
    await controller.abort();
  });

  test('abort failure reports error state instead of false success', () async {
    final controller = AiConversationController(
      supervisor: FakeSupervisor(ready: true),
      clientFactory: () => mockClient,
    );

    final send = controller.sendMessage('Pregunta para abortar');
    await pumpEventQueue();

    mockClient.throwOnAbort = true;
    await controller.abort();
    await pumpEventQueue();

    expect(controller.state.status, AiConversationStatus.error);
    expect(controller.state.errorMessage, contains('Fallo al confirmar la cancelación'));

    await send;
  });

  test('late events after abort are strictly discarded and do not pollute state', () async {
    final controller = AiConversationController(
      supervisor: FakeSupervisor(ready: true),
      clientFactory: () => mockClient,
    );

    final send1 = controller.sendMessage('Pregunta 1');
    await pumpEventQueue();

    mockClient.emitEvent(
      const AiRuntimeEvent(
        type: 'message.part.delta',
        properties: {'delta': 'Respuesta inicial'},
        raw: {},
      ),
    );
    await pumpEventQueue();

    // Abort generation 1
    await controller.abort();
    await pumpEventQueue();

    // A late event arrives from generation 1 after abort
    mockClient.emitEvent(
      const AiRuntimeEvent(
        type: 'message.part.delta',
        properties: {'delta': '... fragmento rezagado que no debe verse'},
        raw: {},
      ),
    );
    await pumpEventQueue();

    // State must NOT have accumulated the late event
    expect(controller.state.streamedText, isEmpty);
    expect(controller.state.messages.last.content, isNot(contains('fragmento rezagado')));

    // Start generation 2
    final send2 = controller.sendMessage('Pregunta 2');
    await pumpEventQueue();

    mockClient.emitEvent(
      const AiRuntimeEvent(
        type: 'message.part.delta',
        properties: {'delta': 'Respuesta limpia 2'},
        raw: {},
      ),
    );
    await pumpEventQueue();

    expect(controller.state.streamedText, 'Respuesta limpia 2');

    mockClient.emitEvent(
      const AiRuntimeEvent(
        type: 'message.completed',
        properties: {},
        raw: {},
      ),
    );
    await pumpEventQueue();

    expect(controller.state.messages.last.content, 'Respuesta limpia 2');

    await send1;
    await send2;
  });

  test('cancelling while connectEvents is pending stops execution without dispatching promptAsync', () async {
    final controller = AiConversationController(
      supervisor: FakeSupervisor(ready: true),
      clientFactory: () => mockClient,
    );

    mockClient.connectEventsDelay = Completer<void>();

    final sendFuture = controller.sendMessage('Pregunta cancelada en conexión');
    await pumpEventQueue();

    // User aborts while connection is still establishing
    await controller.abort();
    await pumpEventQueue();

    // Now connection finishes
    mockClient.connectEventsDelay!.complete();
    await pumpEventQueue();

    // Prompt MUST NOT have been dispatched to the server
    expect(mockClient.promptsSent, isEmpty);
    expect(controller.state.status, AiConversationStatus.idle);

    await sendFuture;
  });

  test('repeating the exact same question does not pick up the previous turn answer', () async {
    final controller = AiConversationController(
      supervisor: FakeSupervisor(ready: true),
      clientFactory: () => mockClient,
    );

    // Prior history already has this exact question and a finished answer
    mockClient.mockMessages = [
      {
        'info': {'role': 'user'},
        'parts': [
          {'type': 'text', 'text': '¿Qué runas uso?'},
        ],
      },
      {
        'info': {'role': 'assistant', 'finish': 'stop'},
        'parts': [
          {'type': 'text', 'text': 'Electrocutar antigua.'},
        ],
      },
    ];

    final send = controller.sendMessage('¿Qué runas uso?');
    await pumpEventQueue();

    // Polling runs while server has not yet added the new response
    await Future<void>.delayed(const Duration(milliseconds: 700));

    // Must NOT have grabbed 'Electrocutar antigua.'
    expect(controller.state.status, AiConversationStatus.streaming);
    expect(controller.state.streamedText, isEmpty);

    // Now the real answer arrives
    mockClient.emitEvent(
      const AiRuntimeEvent(
        type: 'message.part.delta',
        properties: {'delta': 'Cometa arcano nueva.'},
        raw: {},
      ),
    );
    await pumpEventQueue();

    mockClient.emitEvent(
      const AiRuntimeEvent(
        type: 'message.completed',
        properties: {},
        raw: {},
      ),
    );
    await pumpEventQueue();

    expect(controller.state.messages.last.content, 'Cometa arcano nueva.');
    await send;
  });

  test('late event arriving after question 2 has already started is ignored by message/part filter', () async {
    final controller = AiConversationController(
      supervisor: FakeSupervisor(ready: true),
      clientFactory: () => mockClient,
    );

    final send1 = controller.sendMessage('Pregunta 1');
    await pumpEventQueue();
    await controller.abort();
    await pumpEventQueue();

    mockClient.mockMessages = [
      {
        'info': {'id': 'assistant-msg-1', 'role': 'assistant'},
        'parts': [
          {'type': 'text', 'text': 'Respuesta vieja'},
        ],
      },
    ];

    // Start question 2
    final send2 = controller.sendMessage('Pregunta 2');
    await pumpEventQueue();

    // 1. Invertir el orden: el evento tardío de pregunta 1 llega ANTES de la respuesta de pregunta 2
    mockClient.emitEvent(
      const AiRuntimeEvent(
        type: 'message.part.delta',
        properties: {
          'messageId': 'assistant-msg-1',
          'partId': 'part-1',
          'delta': '... residuo peligroso de pregunta 1',
        },
        raw: {},
      ),
    );
    await pumpEventQueue();

    // No debe haberse anclado al residuo ni haber acumulado texto
    expect(controller.state.streamedText, isEmpty);

    // 2. Ahora llega la respuesta verdadera de pregunta 2
    mockClient.emitEvent(
      const AiRuntimeEvent(
        type: 'message.part.delta',
        properties: {
          'messageId': 'assistant-msg-2',
          'partId': 'part-1',
          'delta': 'Inicio de respuesta 2',
        },
        raw: {},
      ),
    );
    await pumpEventQueue();
    expect(controller.state.streamedText, 'Inicio de respuesta 2');

    // Complete question 2
    mockClient.emitEvent(
      const AiRuntimeEvent(
        type: 'message.completed',
        properties: {'messageId': 'assistant-msg-2'},
        raw: {},
      ),
    );
    await pumpEventQueue();

    expect(controller.state.messages.last.content, 'Inicio de respuesta 2');

    await send1;
    await send2;
  });

  test('user message event arriving before assistant response is ignored and does not anchor messageId', () async {
    final controller = AiConversationController(
      supervisor: FakeSupervisor(ready: true),
      clientFactory: () => mockClient,
    );

    final send = controller.sendMessage('¿Qué compro?');
    await pumpEventQueue();

    // Kilo emite primero un evento del mensaje del usuario (eco o actualización de entrada)
    mockClient.emitEvent(
      const AiRuntimeEvent(
        type: 'message.updated',
        properties: {
          'messageId': 'user-msg-echo',
          'role': 'user',
          'text': '¿Qué compro?',
        },
        raw: {},
      ),
    );
    await pumpEventQueue();

    // No debe haber anclado al usuario ni mostrado texto del usuario como respuesta
    expect(controller.state.streamedText, isEmpty);

    // Luego llega el delta legítimo del asistente
    mockClient.emitEvent(
      const AiRuntimeEvent(
        type: 'message.part.delta',
        properties: {
          'messageId': 'assistant-reply-msg',
          'role': 'assistant',
          'delta': 'Compra Rabadon.',
        },
        raw: {},
      ),
    );
    await pumpEventQueue();
    expect(controller.state.streamedText, 'Compra Rabadon.');

    // Completar
    mockClient.emitEvent(
      const AiRuntimeEvent(
        type: 'message.completed',
        properties: {'messageId': 'assistant-reply-msg'},
        raw: {},
      ),
    );
    await pumpEventQueue();

    expect(controller.state.messages.last.role, 'assistant');
    expect(controller.state.messages.last.content, 'Compra Rabadon.');

    await send;
  });
}
