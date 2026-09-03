import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/dependencies.dart';
import '../../../domain/ai/ai_runtime_models.dart';

class AiModelSelector extends ConsumerStatefulWidget {
  const AiModelSelector({super.key});

  @override
  ConsumerState<AiModelSelector> createState() => _AiModelSelectorState();
}

class _AiModelSelectorState extends ConsumerState<AiModelSelector> {
  String? _browsingProvider;

  @override
  Widget build(BuildContext context) {
    final supervisor = ref.watch(aiRuntimeSupervisorProvider);
    final runtime =
        ref.watch(aiRuntimeSupervisorStateProvider).value ?? supervisor.state;
    final catalog = ref.watch(aiModelSelectionProvider);
    final busy = ref.watch(
      aiConversationProvider.select((value) => value.isBusy),
    );
    final controller = ref.read(aiModelSelectionProvider.notifier);
    if (!runtime.isReady) {
      return const Text(
        'Inicia Kilo Code u OpenCode para ver sus modelos disponibles.',
      );
    }
    final selected = catalog.selected;
    final providers = catalog.providers;
    final providerId =
        providers.any((provider) => provider.id == _browsingProvider)
        ? _browsingProvider
        : selected?.providerId ?? providers.firstOrNull?.id;
    final provider = providers
        .where((provider) => provider.id == providerId)
        .firstOrNull;
    final models = [...?provider?.models]
      ..sort((a, b) => a.name.compareTo(b.name));
    final enabled = !busy && !catalog.loading;

    ref.listen(
      aiModelSelectionProvider.select((state) => state.selected?.key),
      (_, _) {
        if (mounted) setState(() => _browsingProvider = null);
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('Motor activo: ${runtime.kind!.displayName}')),
            IconButton(
              tooltip: 'Actualizar modelos',
              onPressed: enabled ? controller.refresh : null,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        if (catalog.loading) ...[
          const LinearProgressIndicator(semanticsLabel: 'Cargando modelos'),
          const SizedBox(height: 8),
          const Text('Cargando modelos disponibles…'),
        ],
        if (catalog.error != null)
          Text(
            catalog.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (!catalog.loading && catalog.error == null && providers.isEmpty)
          const Text(
            'Este motor no tiene proveedores conectados con modelos de chat. '
            'Las cuentas de otras instalaciones no se importan automáticamente.',
          ),
        if (providers.isNotEmpty) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('provider-${runtime.kind?.id}-$providerId'),
            initialValue: providerId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Proveedor de modelos',
            ),
            items: [
              for (final provider in providers)
                DropdownMenuItem(
                  value: provider.id,
                  child: Text(provider.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: enabled
                ? (value) => setState(() => _browsingProvider = value)
                : null,
          ),
          const SizedBox(height: 16),
          DropdownMenu<String>(
            key: ValueKey(
              'model-${runtime.kind?.id}-$providerId-${selected?.key}',
            ),
            enabled: enabled,
            expandedInsets: EdgeInsets.zero,
            menuHeight: 280,
            enableFilter: true,
            requestFocusOnTap: true,
            label: const Text('Modelo'),
            hintText: 'Buscar y seleccionar modelo',
            initialSelection: selected?.providerId == providerId
                ? selected?.key
                : null,
            dropdownMenuEntries: [
              for (final model in models)
                DropdownMenuEntry(
                  value: model.key,
                  label:
                      '${model.name} · ${model.isFree ? "Gratis" : "Costo según proveedor"}',
                  labelWidget: Text(
                    '${model.name}\n${model.id} · ${model.isFree ? "Gratis" : "Costo según proveedor"}',
                  ),
                ),
            ],
            filterCallback: (entries, query) {
              final search = query.toLowerCase();
              return entries
                  .where(
                    (entry) =>
                        entry.label.toLowerCase().contains(search) ||
                        models.any(
                          (model) =>
                              model.key == entry.value &&
                              model.id.toLowerCase().contains(search),
                        ),
                  )
                  .toList();
            },
            onSelected: enabled
                ? (key) {
                    if (key != null) controller.select(key);
                  }
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            selected == null
                ? 'Selecciona un modelo para habilitar el chat.'
                : 'Se usará: ${selected.providerId} / ${selected.name}.',
          ),
          if (selected != null && !selected.isFree)
            const Text(
              'Este modelo puede consumir saldo de tu proveedor al enviar mensajes.',
            ),
        ],
        if (catalog.notice != null) ...[
          const SizedBox(height: 8),
          Text(catalog.notice!),
        ],
        if (busy)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Podrás cambiar de modelo cuando termine la respuesta.',
            ),
          ),
      ],
    );
  }
}
