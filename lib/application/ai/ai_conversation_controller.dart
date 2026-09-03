// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/ai/ai_runtime_api_models.dart';
import '../../domain/ai/ai_runtime_models.dart';
import 'ai_runtime_services.dart';
import 'ai_runtime_supervisor.dart';

enum AiConversationStatus {
  idle,
  connecting,
  sending,
  streaming,
  canceling,
  error,
}

class AiChatMessage {
  const AiChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.isStreaming = false,
  });

  final String id;
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime timestamp;
  final bool isStreaming;

  AiChatMessage copyWith({String? content, bool? isStreaming}) {
    return AiChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      timestamp: timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}

class AiConversationState {
  const AiConversationState({
    this.sessionId,
    this.messages = const [],
    this.status = AiConversationStatus.idle,
    this.streamedText = '',
    this.selectedProviderId = 'kilo',
    this.selectedModelId = 'kilo-auto/free',
    this.errorMessage,
  });

  final String? sessionId;
  final List<AiChatMessage> messages;
  final AiConversationStatus status;
  final String streamedText;
  final String selectedProviderId;
  final String selectedModelId;
  final String? errorMessage;

  bool get isBusy =>
      status == AiConversationStatus.sending ||
      status == AiConversationStatus.streaming ||
      status == AiConversationStatus.canceling ||
      status == AiConversationStatus.connecting;

  bool get canSend => !isBusy;

  AiConversationState copyWith({
    String? sessionId,
    bool clearSessionId = false,
    List<AiChatMessage>? messages,
    AiConversationStatus? status,
    String? streamedText,
    String? selectedProviderId,
    String? selectedModelId,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AiConversationState(
      sessionId: clearSessionId ? null : sessionId ?? this.sessionId,
      messages: messages ?? this.messages,
      status: status ?? this.status,
      streamedText: streamedText ?? this.streamedText,
      selectedProviderId: selectedProviderId ?? this.selectedProviderId,
      selectedModelId: selectedModelId ?? this.selectedModelId,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class AiConversationController extends StateNotifier<AiConversationState> {
  AiConversationController({
    required AiRuntimeSupervisor supervisor,
    required AiRuntimeClient Function() clientFactory,
    DateTime Function()? now,
    AiModelInfo? Function()? modelSelection,
  }) : _supervisor = supervisor,
       _clientFactory = clientFactory,
       _now = now ?? DateTime.now,
       _modelSelection = modelSelection,
       super(const AiConversationState());

  final AiRuntimeSupervisor _supervisor;
  final AiRuntimeClient Function() _clientFactory;
  final DateTime Function() _now;
  final AiModelInfo? Function()? _modelSelection;

  int _currentGenerationId = 0;
  StreamSubscription<AiRuntimeEvent>? _eventsSubscription;
  Timer? _reconciliationTimer;
  AiRuntimeEndpoint? _cachedEndpoint;
  AiRuntimeClient? _client;
  bool _disposed = false;
  bool _turnFinished = false;

  final Map<String, String> _parts = {};
  final Map<String, String> _partTypes = {};
  final Set<String> _userMessageIds = {};
  String? _currentAssistantMessageId;

  AiRuntimeClient get _activeClient {
    final currentEndpoint = _supervisor.state.endpoint;
    if (currentEndpoint == null) {
      throw StateError('El motor de IA local no está encendido.');
    }
    if (_client == null ||
        _cachedEndpoint?.baseUri != currentEndpoint.baseUri ||
        _cachedEndpoint?.password != currentEndpoint.password ||
        _cachedEndpoint?.pid != currentEndpoint.pid) {
      _client?.dispose();
      _client = _clientFactory();
      _cachedEndpoint = currentEndpoint;
      // Si el endpoint cambió (ej. Kilo se apagó y volvió a encender),
      // la sesión previa en el proceso anterior ya no existe en el nuevo servidor.
      if (state.sessionId != null) {
        state = state.copyWith(clearSessionId: true);
      }
    }
    return _client!;
  }

  Future<void> sendMessage(String promptText, {String? systemPrompt}) async {
    final text = promptText.trim();
    if (text.isEmpty || state.isBusy) return;

    if (!_supervisor.state.isReady) {
      state = state.copyWith(
        status: AiConversationStatus.error,
        errorMessage:
            'El motor de IA local no está encendido. Inícialo en Ajustes.',
      );
      return;
    }

    final selected = _modelSelection?.call();
    if (_modelSelection != null && selected == null) {
      state = state.copyWith(
        status: AiConversationStatus.error,
        errorMessage: 'Selecciona un modelo disponible antes de enviar.',
      );
      return;
    }
    final providerId = selected?.providerId ?? state.selectedProviderId;
    final modelId = selected?.id ?? state.selectedModelId;
    final generation = ++_currentGenerationId;
    _turnFinished = false;

    final userMessage = AiChatMessage(
      id: 'user-${_now().microsecondsSinceEpoch}',
      role: 'user',
      content: text,
      timestamp: _now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      status: AiConversationStatus.sending,
      selectedProviderId: providerId,
      selectedModelId: modelId,
      streamedText: '',
      clearError: true,
    );

    try {
      final client = _activeClient;
      var sessionId = state.sessionId;
      if (sessionId == null) {
        final session = await client.createSession(
          title: 'GodSense Coach Chat',
        );
        sessionId = session.id;
        state = state.copyWith(sessionId: sessionId);
      }

      // Obtener la cantidad de mensajes previos y sus IDs conocidos como línea base inmutable
      final initialMessages = await client.messages(sessionId);
      final baselineCount = initialMessages.length;
      final knownPriorMessageIds = initialMessages
          .map(
            (m) =>
                m['info'] is Map ? (m['info'] as Map)['id']?.toString() : null,
          )
          .whereType<String>()
          .toSet();

      // Comprobación anti-cancelación previa a la conexión
      if (_disposed || generation != _currentGenerationId) return;

      // 1. Garantía física de conexión SSE:
      // connectEvents() espera a que el servidor devuelva HTTP 200 para /event
      final eventStream = await client.connectEvents();

      // Comprobación anti-cancelación: si el usuario canceló mientras connectEvents() conectaba
      if (_disposed || generation != _currentGenerationId) return;

      _listenEvents(eventStream, sessionId, generation, knownPriorMessageIds);

      final prompt = AiPrompt(
        providerId: providerId,
        modelId: modelId,
        system:
            systemPrompt ??
            'Eres el asistente táctico de League of Legends de GodSense. '
                'Responde de forma concisa, analítica y sin usar herramientas.',
        text: text,
      );

      // Comprobación estricta inmediatamente antes del promptAsync
      if (_disposed || generation != _currentGenerationId) return;

      // 2. Despacho del prompt solo si no ha sido cancelado
      await client.promptAsync(sessionId, prompt);

      if (_disposed || generation != _currentGenerationId || _turnFinished) {
        return;
      }
      state = state.copyWith(status: AiConversationStatus.streaming);
      _startReconciliation(sessionId, generation, baselineCount);
    } catch (e) {
      if (_disposed || generation != _currentGenerationId) return;
      _stopStreaming();
      state = state.copyWith(
        status: AiConversationStatus.error,
        errorMessage: 'Error al comunicarse con el motor local: $e',
      );
    }
  }

  void _listenEvents(
    Stream<AiRuntimeEvent> stream,
    String targetSessionId,
    int targetGeneration,
    Set<String> knownPriorMessageIds,
  ) {
    _eventsSubscription?.cancel();
    _parts.clear();
    _userMessageIds.clear();
    _currentAssistantMessageId = null;

    _eventsSubscription = stream.listen(
      (event) {
        if (_disposed || targetGeneration != _currentGenerationId) return;
        if (event.sessionId != null && event.sessionId != targetSessionId) {
          return;
        }

        if (event.isError) {
          final err = event.properties['error'] ?? event.raw['error'];
          state = state.copyWith(
            status: AiConversationStatus.error,
            errorMessage: err?.toString() ?? 'Error en la generación.',
          );
          _stopStreaming();
          return;
        }

        // Lifecycle/indexing/sync events must never claim the assistant ID.
        if (!event.type.startsWith('message.')) {
          if (event.isCompleted && _currentAssistantMessageId != null) {
            _commitAssistantMessage(targetGeneration);
          }
          return;
        }

        final msgId = event.messageId;

        // Registrar persistentemente cualquier ID identificado como mensaje del usuario
        if (msgId != null && event.isUser) {
          _userMessageIds.add(msgId);
        }

        // 1. Descartar eventos de mensajes de turnos anteriores (nunca deben anclarse)
        if (msgId != null && knownPriorMessageIds.contains(msgId)) {
          return;
        }

        // 2. Descartar cualquier evento perteneciente al usuario (con o sin role en este evento de parte)
        if (event.isUser ||
            (msgId != null && _userMessageIds.contains(msgId))) {
          return;
        }

        // 3. Anclar únicamente a un mensaje nuevo del asistente
        if (msgId != null) {
          if (_currentAssistantMessageId == null) {
            if (event.role == null || event.isAssistant) {
              _currentAssistantMessageId = msgId;
            } else {
              return;
            }
          } else if (_currentAssistantMessageId != msgId) {
            // Ignorar eventos que pertenezcan a otros mensajes
            return;
          }
        }

        // Reconstrucción estricta de partes por identificador (partId)
        final partKey = event.partId ?? 'default_part';
        final part = event.properties['part'];
        if (part is Map && part['type'] is String) {
          _partTypes[partKey] = part['type'] as String;
        }
        if (_partTypes[partKey] != null && _partTypes[partKey] != 'text') {
          return;
        }

        final delta = event.textDelta;
        if (delta != null && delta.isNotEmpty) {
          _parts[partKey] = (_parts[partKey] ?? '') + delta;
          state = state.copyWith(
            streamedText: _parts.values.join(),
            status: AiConversationStatus.streaming,
          );
        }

        final fullText = event.fullPartText;
        if (fullText != null && fullText.isNotEmpty) {
          _parts[partKey] = fullText;
          state = state.copyWith(
            streamedText: _parts.values.join(),
            status: AiConversationStatus.streaming,
          );
        }

        if (event.isCompleted) {
          // Solo procesar completitud si ya se ha generado texto o si es un evento explícito de mensaje finalizado
          if (state.streamedText.trim().isNotEmpty ||
              event.type == 'message.completed' ||
              (event.type == 'message.updated' &&
                  event.properties['info'] is Map &&
                  (event.properties['info'] as Map)['finish'] != null)) {
            _commitAssistantMessage(targetGeneration);
          }
        }
      },
      onError: (e) {
        // La reconciliación por polling garantiza recuperación ante caídas del stream
      },
    );
  }

  void _startReconciliation(
    String targetSessionId,
    int targetGeneration,
    int baselineCount,
  ) {
    _reconciliationTimer?.cancel();
    var attempts = 0;
    var reading = false;
    _reconciliationTimer = Timer.periodic(const Duration(milliseconds: 600), (
      timer,
    ) async {
      if (_disposed ||
          _turnFinished ||
          targetGeneration != _currentGenerationId ||
          state.sessionId != targetSessionId) {
        timer.cancel();
        return;
      }
      if (reading) return;

      attempts++;
      if (attempts > 100) {
        timer.cancel();
        _stopStreaming();
        if (state.status == AiConversationStatus.streaming) {
          final partial = state.streamedText.trim();
          final errorContent = partial.isNotEmpty
              ? '$partial\n\n[Respuesta incompleta: tiempo de espera agotado]'
              : 'El motor de IA local no completó la respuesta a tiempo.';
          final assistantMessage = AiChatMessage(
            id: 'assistant-${_now().microsecondsSinceEpoch}',
            role: 'assistant',
            content: errorContent,
            timestamp: _now(),
          );
          state = state.copyWith(
            messages: [...state.messages, assistantMessage],
            streamedText: '',
            status: AiConversationStatus.error,
            errorMessage:
                'Tiempo de espera agotado esperando la respuesta del motor.',
          );
        }
        return;
      }

      try {
        reading = true;
        final messages = await _activeClient.messages(targetSessionId);
        if (_disposed ||
            _turnFinished ||
            targetGeneration != _currentGenerationId) {
          timer.cancel();
          return;
        }

        // Correlación estricta por índice posicional y rol:
        // Solo examinamos mensajes posteriores a la línea base de este turno.
        final assistantText = _extractAssistantTextAfter(
          messages,
          baselineCount,
        );
        if (assistantText != null && assistantText.isNotEmpty) {
          if (assistantText.length > state.streamedText.length) {
            state = state.copyWith(streamedText: assistantText);
          }
          if (_isAssistantFinishedAfter(messages, baselineCount)) {
            timer.cancel();
            _commitAssistantMessage(targetGeneration);
          }
        }
      } catch (_) {
        // Ignorar fallo transitorio en polling
      } finally {
        reading = false;
      }
    });
  }

  void _commitAssistantMessage([int? targetGeneration]) {
    if (_turnFinished) return;
    if (targetGeneration != null && targetGeneration != _currentGenerationId) {
      return;
    }
    final text = state.streamedText.trim();
    if (text.isEmpty) {
      // Si aún no hay texto, no cerrar el streaming (ej. eventos iniciales de estado del servidor)
      return;
    }
    _turnFinished = true;
    _stopStreaming();

    final assistantMessage = AiChatMessage(
      id: 'assistant-${_now().microsecondsSinceEpoch}',
      role: 'assistant',
      content: text,
      timestamp: _now(),
    );

    state = state.copyWith(
      messages: [...state.messages, assistantMessage],
      streamedText: '',
      status: AiConversationStatus.idle,
    );
  }

  void _stopStreaming() {
    _eventsSubscription?.cancel();
    _eventsSubscription = null;
    _reconciliationTimer?.cancel();
    _reconciliationTimer = null;
    _parts.clear();
    _partTypes.clear();
    _userMessageIds.clear();
    _currentAssistantMessageId = null;
  }

  Future<void> abort() async {
    final sessionId = state.sessionId;
    if (sessionId == null || !state.isBusy) return;

    _currentGenerationId++; // Invalida cualquier evento en vuelo o rezagado
    state = state.copyWith(status: AiConversationStatus.canceling);
    _stopStreaming();

    try {
      await _activeClient.abort(sessionId);
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(
        status: AiConversationStatus.error,
        errorMessage: 'Fallo al confirmar la cancelación en el motor local: $e',
      );
      return;
    }

    if (_disposed) return;
    if (state.streamedText.trim().isNotEmpty) {
      final truncated = '${state.streamedText.trim()} [Cancelado]';
      final partialMessage = AiChatMessage(
        id: 'assistant-${_now().microsecondsSinceEpoch}',
        role: 'assistant',
        content: truncated,
        timestamp: _now(),
      );
      state = state.copyWith(
        messages: [...state.messages, partialMessage],
        streamedText: '',
        status: AiConversationStatus.idle,
      );
    } else {
      state = state.copyWith(status: AiConversationStatus.idle);
    }
  }

  Future<void> clearConversation() async {
    _currentGenerationId++;
    _stopStreaming();
    final currentSession = state.sessionId;
    state = state.copyWith(
      messages: const [],
      streamedText: '',
      clearSessionId: true,
      clearError: true,
      status: AiConversationStatus.idle,
    );

    if (currentSession != null) {
      try {
        await _activeClient.deleteSession(currentSession);
      } catch (_) {}
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true, status: AiConversationStatus.idle);
  }

  static String? _extractAssistantTextAfter(
    List<Map<String, dynamic>> messages,
    int baselineCount,
  ) {
    for (var i = baselineCount; i < messages.length; i++) {
      final msg = messages[i];
      final info = msg['info'];
      if (info is! Map || info['role'] != 'assistant') continue;
      final parts = msg['parts'];
      if (parts is! List) continue;
      final text = parts
          .whereType<Map>()
          .where((p) => p['type'] == 'text')
          .map((p) => p['text']?.toString() ?? '')
          .join();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static bool _isAssistantFinishedAfter(
    List<Map<String, dynamic>> messages,
    int baselineCount,
  ) {
    for (var i = baselineCount; i < messages.length; i++) {
      final msg = messages[i];
      final info = msg['info'];
      if (info is! Map || info['role'] != 'assistant') continue;
      final finish = info['finish'];
      if (finish != null && finish.toString() != 'null') return true;
      final status = info['status']?.toString();
      if (status == 'completed' || status == 'idle') return true;
    }
    return false;
  }

  @override
  void dispose() {
    _disposed = true;
    _stopStreaming();
    _client?.dispose();
    super.dispose();
  }
}
