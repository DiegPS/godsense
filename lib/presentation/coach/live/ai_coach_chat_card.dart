import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/ai/ai_conversation_controller.dart';
import '../../../application/dependencies.dart';
import '../../../domain/ai/ai_runtime_models.dart';
import '../shared/coach_surface.dart';
import '../shared/ai_model_selector.dart';
import 'coach_message_body.dart';

class AiCoachChatCard extends ConsumerStatefulWidget {
  const AiCoachChatCard({super.key});

  @override
  ConsumerState<AiCoachChatCard> createState() => _AiCoachChatCardState();
}

class _AiCoachChatCardState extends ConsumerState<AiCoachChatCard> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _startingRuntime = false;

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

  void _sendMessage([String? presetText]) {
    final text = presetText ?? _textController.text;
    if (text.trim().isEmpty) return;
    _textController.clear();

    String? systemPrompt;
    try {
      systemPrompt = ref.read(gameContextPromptProvider);
    } catch (_) {}

    ref
        .read(aiConversationProvider.notifier)
        .sendMessage(text, systemPrompt: systemPrompt);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
      aiConversationProvider.select((s) => s.streamedText),
      (_, _) => _scrollToBottom(),
    );

    return CoachSurface(
      title: 'Coach IA conversacional',
      subtitle: supervisorState.isReady
          ? '${supervisorState.kind!.displayName} · ${selectedModel?.name ?? "Selecciona un modelo"}'
          : 'Instala un motor en Ajustes → Coaching y actívalo para chatear',
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
                setState(() => _startingRuntime = true);
                try {
                  if (!await supervisor.isInstalled(kind)) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Descarga ${kind.displayName} en Ajustes → Coaching antes de iniciar.',
                          ),
                        ),
                      );
                    }
                    return;
                  }
                  await supervisor.start(kind);
                  await ref
                      .read(aiRuntimeSettingsProvider)
                      .rememberStarted(kind);
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
          if (supervisorState.isReady) ...[
            const ExpansionTile(
              title: Text('Proveedor y modelo'),
              children: [
                Padding(padding: EdgeInsets.all(12), child: AiModelSelector()),
              ],
            ),
            const SizedBox(height: 12),
          ],
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
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 340, minHeight: 120),
            child:
                conversation.messages.isEmpty &&
                    conversation.streamedText.isEmpty
                ? Center(
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
                              : 'Inicia Kilo Code para consultar al Coach con IA.',
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
                : ListView(
                    controller: _scrollController,
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      for (final message in conversation.messages)
                        _ChatBubble(message: message),
                      if (conversation.streamedText.isNotEmpty)
                        _StreamingBubble(text: conversation.streamedText),
                    ],
                  ),
          ),
          if (isBusy) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    conversation.status == AiConversationStatus.sending
                        ? 'Enviando al motor Kilo Auto...'
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
                child: TextField(
                  controller: _textController,
                  enabled: isReady && !isBusy,
                  textInputAction: TextInputAction.send,
                  onSubmitted: isReady && !isBusy
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
                      borderSide: const BorderSide(color: CoachColors.cyan),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: isReady && !isBusy ? () => _sendMessage() : null,
                icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: CoachColors.cyan,
                  foregroundColor: const Color(0xFF041017),
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
              ? CoachColors.cyan.withValues(alpha: .16)
              : CoachColors.elevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isUser
                ? CoachColors.cyan.withValues(alpha: .4)
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
                  color: isUser ? CoachColors.cyan : CoachColors.emerald,
                ),
                const SizedBox(width: 4),
                Text(
                  isUser ? 'Tú' : 'Coach IA',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isUser ? CoachColors.cyan : CoachColors.emerald,
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
                Text(
                  'Coach IA (escribiendo...)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: CoachColors.emerald,
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
