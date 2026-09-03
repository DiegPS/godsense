// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/ai/ai_runtime_api_models.dart';
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
  AiRuntimeClient? _client;
  bool _disposed = false;

  AiRuntimeClient get _activeClient => _client ??= _clientFactory();

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

      // Orden estricto: suscribirse primero a eventos antes de emitir el prompt
      _listenEvents(sessionId, generation);

      final prompt = AiPrompt(
        providerId: state.selectedProviderId,
        modelId: state.selectedModelId,
        system: systemPrompt ??
            'Eres el asistente táctico de League of Legends de GodSense. '
            'Responde de forma concisa, analítica y sin usar herramientas.',
        text: text,
      );

      await client.promptAsync(sessionId, prompt);

      if (_disposed || generation != _currentGenerationId) return;
      state = state.copyWith(status: AiConversationStatus.streaming);
      _startReconciliation(sessionId, generation);
    } catch (e) {
      if (_disposed || generation != _currentGenerationId) return;
      _stopStreaming();
      state = state.copyWith(
        status: AiConversationStatus.error,
        errorMessage: 'Error al comunicarse con el motor local: $e',
      );
    }
  }

  void _listenEvents(String targetSessionId, int targetGeneration) {
    _eventsSubscription?.cancel();
    try {
      _eventsSubscription = _activeClient.events().listen(
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

          final delta = event.textDelta;
          if (delta != null && delta.isNotEmpty) {
            state = state.copyWith(
              streamedText: state.streamedText + delta,
              status: AiConversationStatus.streaming,
            );
          }

          if (event.isCompleted) {
            _commitAssistantMessage(targetGeneration);
          }
        },
        onError: (e) {
          // El stream SSE puede desconectarse; la reconciliación por polling completará la respuesta
        },
      );
    } catch (_) {
      // Ignorar fallo de SSE inmediato; el polling resolverá
    }
  }

  void _startReconciliation(String targetSessionId, int targetGeneration) {
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
          final assistantText = _extractAssistantText(messages);
          if (assistantText != null && assistantText.isNotEmpty) {
            if (assistantText.length > state.streamedText.length) {
              state = state.copyWith(streamedText: assistantText);
            }
            if (_isAssistantFinished(messages)) {
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
    } catch (_) {
      // Si el abort falla (ej. ya había terminado en el servidor), continuar limpiamente
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

  static String? _extractAssistantText(List<Map<String, dynamic>> messages) {
    for (final message in messages.reversed) {
      final info = message['info'];
      if (info is! Map || info['role'] != 'assistant') continue;
      final parts = message['parts'];
      if (parts is! List) continue;
      final text = parts
          .whereType<Map>()
          .where((part) => part['type'] == 'text')
          .map((part) => part['text']?.toString() ?? '')
          .join();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static bool _isAssistantFinished(List<Map<String, dynamic>> messages) {
    for (final message in messages.reversed) {
      final info = message['info'];
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
