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

  AiChatMessage copyWith({
    String? content,
    bool? isStreaming,
  }) {
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
  }) : _supervisor = supervisor,
       _clientFactory = clientFactory,
       _now = now ?? DateTime.now,
       super(const AiConversationState());

  final AiRuntimeSupervisor _supervisor;
  final AiRuntimeClient Function() _clientFactory;
  final DateTime Function() _now;

  int _currentGenerationId = 0;
  StreamSubscription<AiRuntimeEvent>? _eventsSubscription;
  Timer? _reconciliationTimer;
  AiRuntimeEndpoint? _cachedEndpoint;
  AiRuntimeClient? _client;
  bool _disposed = false;

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

  Future<void> sendMessage(
    String promptText, {
    String? systemPrompt,
  }) async {
    final text = promptText.trim();
    if (text.isEmpty || state.isBusy) return;

    if (!_supervisor.state.isReady) {
      state = state.copyWith(
        status: AiConversationStatus.error,
        errorMessage: 'El motor de IA local no está encendido. Inícialo en Ajustes.',
      );
      return;
    }

    final generation = ++_currentGenerationId;

    final userMessage = AiChatMessage(
      id: 'user-${_now().microsecondsSinceEpoch}',
      role: 'user',
      content: text,
      timestamp: _now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      status: AiConversationStatus.sending,
      streamedText: '',
      clearError: true,
    );

    try {
      final client = _activeClient;
      var sessionId = state.sessionId;
      if (sessionId == null) {
        final session = await client.createSession(title: 'GodSense Coach Chat');
        sessionId = session.id;
        state = state.copyWith(sessionId: sessionId);
      }

      // 1. Garantía física de conexión SSE:
      // connectEvents() espera a que el servidor devuelva HTTP 200 para /event
      // antes de enviar el prompt, asegurando no perder los primeros eventos.
      final eventStream = await client.connectEvents();
      _listenEvents(eventStream, sessionId, generation);

      final prompt = AiPrompt(
        providerId: state.selectedProviderId,
        modelId: state.selectedModelId,
        system: systemPrompt ??
            'Eres el asistente táctico de League of Legends de GodSense. '
            'Responde de forma concisa, analítica y sin usar herramientas.',
        text: text,
      );

      // 2. Despacho del prompt solo tras verificar el SSE activo
      await client.promptAsync(sessionId, prompt);

      if (_disposed || generation != _currentGenerationId) return;
      state = state.copyWith(status: AiConversationStatus.streaming);
      _startReconciliation(sessionId, generation, text);
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
  ) {
    _eventsSubscription?.cancel();
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

        // Manejo diferenciado: fragmento incremental vs texto completo de la parte
        final delta = event.textDelta;
        if (delta != null && delta.isNotEmpty) {
          state = state.copyWith(
            streamedText: state.streamedText + delta,
            status: AiConversationStatus.streaming,
          );
        }

        final fullText = event.fullPartText;
        if (fullText != null && fullText.isNotEmpty) {
          if (fullText.length >= state.streamedText.length) {
            state = state.copyWith(
              streamedText: fullText,
              status: AiConversationStatus.streaming,
            );
          }
        }

        if (event.isCompleted) {
          _commitAssistantMessage(targetGeneration);
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
    String targetPromptText,
  ) {
    _reconciliationTimer?.cancel();
    var attempts = 0;
    _reconciliationTimer = Timer.periodic(
      const Duration(milliseconds: 600),
      (timer) async {
        if (_disposed ||
            targetGeneration != _currentGenerationId ||
            state.sessionId != targetSessionId) {
          timer.cancel();
          return;
        }

        attempts++;
        if (attempts > 100) {
          timer.cancel();
          if (state.status == AiConversationStatus.streaming) {
            _commitAssistantMessage(targetGeneration);
          }
          return;
        }

        try {
          final messages = await _activeClient.messages(targetSessionId);
          if (targetGeneration != _currentGenerationId) {
            timer.cancel();
            return;
          }

          // Correlación estricta: buscar la respuesta del asistente que corresponde
          // EXCLUSIVAMENTE a este prompt específico, nunca a preguntas previas.
          final assistantText = _extractAssistantTextForPrompt(
            messages,
            targetPromptText,
          );
          if (assistantText != null && assistantText.isNotEmpty) {
            if (assistantText.length > state.streamedText.length) {
              state = state.copyWith(streamedText: assistantText);
            }
            if (_isAssistantFinishedForPrompt(messages, targetPromptText)) {
              timer.cancel();
              _commitAssistantMessage(targetGeneration);
            }
          }
        } catch (_) {
          // Ignorar fallo transitorio en polling
        }
      },
    );
  }

  void _commitAssistantMessage([int? targetGeneration]) {
    if (targetGeneration != null && targetGeneration != _currentGenerationId) {
      return;
    }
    _stopStreaming();
    final text = state.streamedText.trim();
    if (text.isEmpty) {
      state = state.copyWith(status: AiConversationStatus.idle);
      return;
    }

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

  static int _findUserMessageIndexForPrompt(
    List<Map<String, dynamic>> messages,
    String targetPromptText,
  ) {
    for (var i = messages.length - 1; i >= 0; i--) {
      final msg = messages[i];
      final info = msg['info'];
      if (info is! Map || info['role'] != 'user') continue;
      final parts = msg['parts'];
      if (parts is! List) continue;
      final userText = parts
          .whereType<Map>()
          .where((p) => p['type'] == 'text')
          .map((p) => p['text']?.toString() ?? '')
          .join();
      if (userText.trim() == targetPromptText.trim()) {
        return i;
      }
    }
    return -1;
  }

  static String? _extractAssistantTextForPrompt(
    List<Map<String, dynamic>> messages,
    String targetPromptText,
  ) {
    final userIdx = _findUserMessageIndexForPrompt(messages, targetPromptText);
    if (userIdx == -1) return null;

    for (var i = userIdx + 1; i < messages.length; i++) {
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

  static bool _isAssistantFinishedForPrompt(
    List<Map<String, dynamic>> messages,
    String targetPromptText,
  ) {
    final userIdx = _findUserMessageIndexForPrompt(messages, targetPromptText);
    if (userIdx == -1) return false;

    for (var i = userIdx + 1; i < messages.length; i++) {
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
