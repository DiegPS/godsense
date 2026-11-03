import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_consistent_ui/flutter_consistent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/dependencies.dart';
import '../../../domain/ai/ai_runtime_api_models.dart';
import '../../../domain/ai/ai_runtime_models.dart';

class AiChatModelPicker extends ConsumerStatefulWidget {
  const AiChatModelPicker({super.key});
  @override
  ConsumerState<AiChatModelPicker> createState() => _AiChatModelPickerState();
}

class _AiChatModelPickerState extends ConsumerState<AiChatModelPicker> {
  final _menu = MenuController();

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(aiModelSelectionProvider);
    final busy = ref.watch(
      aiConversationProvider.select((state) => state.isBusy),
    );
    final supervisor = ref.watch(aiRuntimeSupervisorProvider);
    final runtime =
        ref.watch(aiRuntimeSupervisorStateProvider).value ?? supervisor.state;
    final label =
        '${runtime.kind?.displayName ?? 'IA'} · ${catalog.selected?.name ?? 'Seleccionar modelo'}';
    final size = MediaQuery.sizeOf(context);
    return MenuAnchor(
      controller: _menu,
      consumeOutsideTap: true,
      style: MenuStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        backgroundColor: WidgetStatePropertyAll(
          Theme.of(context).colorScheme.surface,
        ),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              UiThemeData.of(context).panelRadius,
            ),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
      ),
      menuChildren: [
        SizedBox(
          width: math.min(420.0, math.max(0.0, size.width - 32)),
          height: math.min(520.0, math.max(0.0, size.height - 100)),
          child: AiChatModelOptions(onSelected: _menu.close),
        ),
      ],
      builder: (context, controller, child) => Tooltip(
        message: busy
            ? 'Podrás cambiar de modelo cuando termine la respuesta'
            : 'Cambiar modelo de IA',
        child: TextButton.icon(
          key: const Key('chat-model-picker'),
          onPressed: busy
              ? null
              : () {
                  if (size.width < 600) {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      showDragHandle: true,
                      builder: (sheetContext) => Padding(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
                        ),
                        child: AiChatModelOptions(
                          onSelected: () => Navigator.of(sheetContext).pop(),
                        ),
                      ),
                    );
                  } else {
                    controller.isOpen ? controller.close() : controller.open();
                  }
                },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            side: BorderSide.none,
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
            textStyle: Theme.of(context).textTheme.bodySmall,
            alignment: AlignmentDirectional.centerStart,
          ),
          icon: const Icon(Icons.expand_more_rounded, size: 18),
          iconAlignment: IconAlignment.end,
          label: Text(label),
        ),
      ),
    );
  }
}

class AiChatModelOptions extends ConsumerStatefulWidget {
  const AiChatModelOptions({super.key, required this.onSelected});
  final VoidCallback onSelected;
  @override
  ConsumerState<AiChatModelOptions> createState() => _AiChatModelOptionsState();
}

class _AiChatModelOptionsState extends ConsumerState<AiChatModelOptions> {
  final _query = TextEditingController();
  final _scroll = ScrollController();
  bool _selecting = false;
  String? _selectionError;

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _select(AiModelInfo model) async {
    if (_selecting || ref.read(aiConversationProvider).isBusy) return;
    final controller = ref.read(aiModelSelectionProvider.notifier);
    setState(() {
      _selecting = true;
      _selectionError = null;
    });
    try {
      await controller.select(model.key);
      if (mounted &&
          ref.read(aiModelSelectionProvider).selected?.key == model.key) {
        widget.onSelected();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _selectionError =
              'No se pudo cambiar el modelo. Inténtalo de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _selecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(aiModelSelectionProvider);
    final busy = ref.watch(
      aiConversationProvider.select((state) => state.isBusy),
    );
    final enabled = !busy && !catalog.loading && !_selecting;
    final search = _query.text.trim().toLowerCase();
    final rows = <({String provider, AiModelInfo? model})>[];
    final providers = [...catalog.providers]
      ..sort((a, b) => a.name.compareTo(b.name));
    for (final provider in providers) {
      final providerMatches = '${provider.name} ${provider.id}'
          .toLowerCase()
          .contains(search);
      final models =
          provider.models
              .where(
                (model) =>
                    providerMatches ||
                    '${model.name} ${model.id}'.toLowerCase().contains(search),
              )
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
      if (models.isEmpty) continue;
      rows.add((provider: provider.name, model: null));
      rows.addAll(
        models.map((model) => (provider: provider.name, model: model)),
      );
    }
    final availableHeight = math.max(
      0.0,
      MediaQuery.sizeOf(context).height -
          MediaQuery.viewInsetsOf(context).bottom -
          100,
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: math.min(520, availableHeight)),
      child: Scrollbar(
        controller: _scroll,
        child: CustomScrollView(
          key: const Key('chat-model-options'),
          controller: _scroll,
          primary: false,
          shrinkWrap: true,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Elegir modelo',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    UiControls.input(
                      controller: _query,
                      decoration: InputDecoration(
                        hintText: 'Buscar modelo o proveedor',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          tooltip: 'Actualizar modelos',
                          onPressed: enabled
                              ? ref
                                    .read(aiModelSelectionProvider.notifier)
                                    .refresh
                              : null,
                          icon: const Icon(Icons.refresh),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (catalog.loading) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(
                        semanticsLabel: 'Cargando modelos',
                      ),
                    ],
                    if (_selectionError ?? catalog.error case final error?) ...[
                      const SizedBox(height: 8),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          error,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                    if (catalog.notice != null) Text(catalog.notice!),
                    if (busy)
                      const Text(
                        'Podrás cambiar de modelo cuando termine la respuesta.',
                      ),
                    if (!catalog.loading && rows.isEmpty)
                      Text(
                        search.isEmpty
                            ? 'No hay modelos disponibles. Actualiza la lista o revisa el motor en Ajustes.'
                            : 'No hay modelos que coincidan con tu búsqueda.',
                      ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsetsDirectional.only(
                start: 8,
                end: 20,
                bottom: 12,
              ),
              sliver: SliverList.builder(
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  final model = row.model;
                  if (model == null) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                      child: Semantics(
                        header: true,
                        child: Text(
                          row.provider,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                    );
                  }
                  final selected = model.key == catalog.selected?.key;
                  return ListTile(
                    key: ValueKey('chat-model-${model.key}'),
                    enabled: enabled,
                    selected: selected,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        UiThemeData.of(context).controlRadius,
                      ),
                    ),
                    selectedTileColor: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                    title: Text(model.name),
                    subtitle: Text(
                      '${model.id} · ${model.isFree ? 'Gratis' : 'Puede consumir saldo del proveedor'}',
                    ),
                    trailing: selected
                        ? const Icon(Icons.check_circle_outline)
                        : null,
                    onTap: enabled ? () => _select(model) : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
