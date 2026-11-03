import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:godsense/presentation/shared/gs_tokens.dart';
import 'package:flutter_consistent_ui/flutter_consistent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/ai/ai_conversation_controller.dart';
import '../../../application/dependencies.dart';
import '../../../domain/ai/ai_runtime_models.dart';
import '../shared/coach_surface.dart';
import '../shared/ai_chat_model_picker.dart';
import 'coach_message_body.dart';

class AiCoachChatCard extends ConsumerStatefulWidget {
  const AiCoachChatCard({super.key});

  @override
  ConsumerState<AiCoachChatCard> createState() => _AiCoachChatCardState();
}

class _AiCoachChatCardState extends ConsumerState<AiCoachChatCard>
    with AutomaticKeepAliveClientMixin<AiCoachChatCard> {
  @override
  bool get wantKeepAlive => true;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _startingRuntime = false;
  bool _submitting = false;
  bool _followLatest = true;
  bool _followRebuildScheduled = false;
  bool _scrollScheduled = false;
  bool _movingToLatest = false;

  @override
  void initState() {
    super.initState();
    _scrollToBottom();
  }

  static const _suggestions = [
    '¿Cuál es mi condición de victoria?',
    '¿Cómo jugar la fase de líneas?',
    '¿Qué priorizar en peleas de equipo?',
  ];

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = presetText ?? _textController.text;
    if (text.trim().isEmpty || _submitting) return;
    final controller = ref.read(aiConversationProvider.notifier);
    final previousIds = ref
        .read(aiConversationProvider)
        .messages
        .map((m) => m.id)
        .toSet();
    setState(() => _submitting = true);
    String? systemPrompt;
    try {
      systemPrompt = ref.read(gameContextPromptProvider);
    } catch (_) {}
    try {
      await controller.sendMessage(text, systemPrompt: systemPrompt);
      if (!mounted) return;
      final accepted = ref
          .read(aiConversationProvider)
          .messages
          .any(
            (message) =>
                message.role == 'user' &&
                !previousIds.contains(message.id) &&
                message.content == text.trim(),
          );
      // Rejection must never eat a draft. A delayed acknowledgement must not
      // erase edits the user made while dispatch was being established.
      if (accepted) {
        if (presetText == null && _textController.text == text) {
          _textController.clear();
        }
        _scrollToBottom(force: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _scrollToBottom({bool force = false}) {
    if (force) _setFollowLatest(true);
    if (!_followLatest || _scrollScheduled) return;
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (mounted && _followLatest && _scrollController.hasClients) {
        _movingToLatest = true;
        try {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        } finally {
          _movingToLatest = false;
        }
      }
    });
  }

  void _setFollowLatest(bool follow) {
    if (_followLatest == follow) return;
    _followLatest = follow;
    // Viewport dimension changes can emit notifications during layout. Update
    // follow policy immediately, but rebuild its button after that frame.
    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_followRebuildScheduled) return;
      _followRebuildScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _followRebuildScheduled = false;
        if (mounted) setState(() {});
      });
    } else if (mounted) {
      setState(() {});
    }
  }

  bool _trackHistoryScroll(ScrollNotification notification) {
    if (notification.depth != 0 || _movingToLatest) return false;
    // Wheel direction is emitted before pixels change. Pause immediately on
    // upward intent, even for a single notch at the very end of the history.
    if (notification is UserScrollNotification &&
            notification.direction == ScrollDirection.forward ||
        notification is ScrollStartNotification &&
            notification.dragDetails != null) {
      _setFollowLatest(false);
    } else if (notification is ScrollEndNotification ||
        notification is UserScrollNotification &&
            notification.direction == ScrollDirection.idle) {
      // Only resume when the user actually reaches the bottom, not merely
      // somewhere within a threshold of it. Programmatic following already
      // checks _followLatest before moving the position.
      final follow = notification.metrics.extentAfter <= 1;
      _setFollowLatest(follow);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final conversation = ref.watch(aiConversationProvider);
    final supervisor = ref.watch(aiRuntimeSupervisorProvider);
    final supervisorState =
        ref.watch(aiRuntimeSupervisorStateProvider).value ?? supervisor.state;
    final models = ref.watch(aiModelSelectionProvider);
    final selectedModel = models.selected;
    final isReady =
        supervisorState.isReady && !models.loading && selectedModel != null;
    final isBusy = conversation.isBusy;

    ref.listen(
      aiConversationProvider.select((s) => (s.streamedText, s.messages.length)),
      (_, _) => _scrollToBottom(),
    );

    return CoachSurface(
      title: 'Coach IA conversacional',
      subtitle: supervisorState.isReady ? null : 'Instala un motor en Ajustes → IA del coach y actívalo para chatear',
      headerCenter: supervisorState.isReady ? const AiChatModelPicker() : null,
      icon: Icons.psychology_rounded,
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (supervisorState.isReady)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: CoachColors.emerald.withValues(alpha: .15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: CoachColors.emerald.withValues(alpha: .4),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(radius: 3, backgroundColor: CoachColors.emerald),
                  SizedBox(width: 5),
                  Text(
                    'CONECTADO',
                    style: TextStyle(
                      color: CoachColors.emerald,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            )
          else
            PopupMenuButton<AiRuntimeKind>(
              tooltip: 'Iniciar motor',
              enabled: !_startingRuntime && !supervisorState.isBusy && !isBusy,
              itemBuilder: (_) => [
                for (final kind in AiRuntimeKind.values)
                  PopupMenuItem(
                    value: kind,
                    child: Text('Iniciar ${kind.displayName}'),
                  ),
              ],
              onSelected: (kind) async {
                final settings = ref.read(aiRuntimeSettingsProvider);
                setState(() => _startingRuntime = true);
                try {
                  if (!await supervisor.isInstalled(kind)) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Descarga ${kind.displayName} en Ajustes → IA del coach antes de iniciar.',
                          ),
                        ),
                      );
                    }
                    return;
                  }
                  await supervisor.start(kind);
                  await settings.rememberStarted(kind);
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'No se pudo iniciar ${kind.displayName}: $error',
                        ),
                      ),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _startingRuntime = false);
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_startingRuntime ? 'Iniciando…' : 'Iniciar motor'),
              ),
            ),
          if (conversation.messages.isNotEmpty) ...[
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Limpiar chat',
              icon: const Icon(Icons.delete_outline_rounded, size: 16),
              onPressed: isBusy
                  ? null
                  : () => ref
                        .read(aiConversationProvider.notifier)
                        .clearConversation(),
            ),
          ],
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (conversation.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: CoachColors.crimson.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: CoachColors.crimson.withValues(alpha: .3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 16,
                    color: CoachColors.crimson,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      conversation.errorMessage!,
                      style: const TextStyle(
                        color: CoachColors.crimson,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.read(aiConversationProvider.notifier).clearError(),
                    child: const Text('Cerrar', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
          ],
          if (conversation.messages.isEmpty &&
              conversation.streamedText.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 32,
                    color: CoachColors.mutedText,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isReady
                        ? 'Escribe una pregunta táctica o elige una sugerencia.'
                        : 'Inicia un motor para consultar al Coach con IA.',
                    style: const TextStyle(
                      color: CoachColors.secondaryText,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (isReady) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      runSpacing: 6,
                      children: _suggestions.map((suggestion) {
                        return ActionChip(
                          label: Text(
                            suggestion,
                            softWrap: true,
                            style: const TextStyle(fontSize: 11),
                          ),
                          onPressed: isBusy
                              ? null
                              : () => _sendMessage(suggestion),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: (MediaQuery.sizeOf(context).height * .45).clamp(
                  160,
                  420,
                ),
              ),
              child: NotificationListener<ScrollMetricsNotification>(
                onNotification: (_) {
                  _scrollToBottom();
                  return false;
                },
                child: NotificationListener<ScrollNotification>(
                  onNotification: _trackHistoryScroll,
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context)
                        .copyWith(scrollbars: false),
                    child: Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      interactive: true,
                      thickness: 8,
                      radius: const Radius.circular(4),
                      child: ListView.builder(
                        key: const Key('coach-chat-history'),
                        controller: _scrollController,
                        primary: false,
                        shrinkWrap: true,
                        padding: const EdgeInsetsDirectional.only(
                          top: 8,
                          bottom: 8,
                          end: 20,
                        ),
                        itemCount:
                            conversation.messages.length +
                            (conversation.streamedText.isNotEmpty ? 1 : 0),
                        itemBuilder: (context, index) =>
                            index < conversation.messages.length
                            ? _ChatBubble(message: conversation.messages[index])
                            : _StreamingBubble(text: conversation.streamedText),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (!_followLatest)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: () => _scrollToBottom(force: true),
                icon: const Icon(Icons.arrow_downward),
                label: const Text('Ir al último mensaje'),
              ),
            ),
          if (isBusy) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                Text(
                  conversation.status == AiConversationStatus.sending
                      ? 'Enviando al motor de IA...'
                      : conversation.status == AiConversationStatus.canceling
                      ? 'Cancelando respuesta...'
                      : conversation.streamedText.isEmpty
                      ? 'Esperando respuesta...'
                      : 'Escribiendo respuesta...',
                  style: const TextStyle(
                    color: CoachColors.secondaryText,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                TextButton.icon(
                  onPressed:
                      conversation.status == AiConversationStatus.canceling
                      ? null
                      : () => ref.read(aiConversationProvider.notifier).abort(),
                  icon: const Icon(
                    Icons.stop_circle_outlined,
                    size: 14,
                    color: CoachColors.crimson,
                  ),
                  label: const Text(
                    'Cancelar generación',
                    style: TextStyle(color: CoachColors.crimson, fontSize: 11),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    minimumSize: const Size(40, 40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: UiControls.input(
                  controller: _textController,
                  enabled: isReady && !isBusy && !_submitting,
                  textInputAction: TextInputAction.send,
                  onSubmitted: isReady && !isBusy && !_submitting
                      ? (_) => _sendMessage()
                      : null,
                  style: const TextStyle(
                    color: CoachColors.primaryText,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: isReady
                        ? 'Pregunta al coach de IA (ej: condición de victoria)...'
                        : 'Inicia el motor local para habilitar el chat...',
                    hintStyle: const TextStyle(
                      color: CoachColors.mutedText,
                      fontSize: 13,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: CoachColors.elevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: CoachColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: CoachColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: CoachColors.accent),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: isReady && !isBusy && !_submitting
                    ? () => _sendMessage()
                    : null,
                icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: CoachColors.accent,
                  foregroundColor: GsColors.onAccent,
                  disabledBackgroundColor: CoachColors.mutedText.withValues(
                    alpha: .2,
                  ),
                  disabledForegroundColor: CoachColors.mutedText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final AiChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: isUser
              ? CoachColors.accent.withValues(alpha: .16)
              : CoachColors.elevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isUser
                ? CoachColors.accent.withValues(alpha: .4)
                : CoachColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isUser ? Icons.person_rounded : Icons.psychology_rounded,
                  size: 13,
                  color: isUser ? CoachColors.accent : CoachColors.emerald,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    isUser ? 'Tú' : 'Coach IA',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isUser ? CoachColors.accent : CoachColors.emerald,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (isUser)
              SelectableText(
                message.content,
                style: const TextStyle(
                  color: CoachColors.primaryText,
                  fontSize: 14,
                  height: 1.5,
                ),
              )
            else
              CoachMessageBody(text: message.content),
            if (message.isCancelled) ...[
              const SizedBox(height: 4),
              const Text(
                'Cancelado',
                style: TextStyle(fontSize: 11, color: CoachColors.mutedText),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StreamingBubble extends StatelessWidget {
  const _StreamingBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: CoachColors.elevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: CoachColors.emerald.withValues(alpha: .4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.psychology_rounded,
                  size: 13,
                  color: CoachColors.emerald,
                ),
                SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Coach IA (escribiendo...)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: CoachColors.emerald,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            CoachMessageBody(text: text),
          ],
        ),
      ),
    );
  }
}
