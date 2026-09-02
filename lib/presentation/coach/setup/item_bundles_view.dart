import 'package:flutter/material.dart';

import '../../../application/coach_controller.dart';
import '../shared/asset_portrait.dart';
import '../shared/coach_surface.dart';

class ItemBundlesView extends StatelessWidget {
  const ItemBundlesView({
    super.key,
    required this.groups,
    required this.importing,
    required this.onImport,
  });

  final List<RecommendedItemGroupViewData> groups;
  final bool importing;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return CoachSurface(
      title: 'Sets de objetos recomendados por Riot',
      icon: Icons.inventory_2_outlined,
      action: IconButton(
        tooltip: 'Importar set de objetos en League',
        onPressed: groups.isEmpty || importing ? null : onImport,
        icon: const Icon(Icons.download_outlined),
      ),
      child: groups.isEmpty
          ? const CoachEmptyState(
              message: 'Esperando recomendaciones para campeón y posición.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final group in groups) ...[
                  Text(
                    group.title,
                    style: const TextStyle(
                      color: CoachColors.secondaryText,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final value in group.items)
                        Tooltip(
                          message:
                              '${value.metadata?.name ?? value.item.name}\n'
                              '${value.metadata?.totalPrice ?? 0} oro\n'
                              '${value.metadata?.description ?? 'Metadatos pendientes'}',
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AssetPortrait(
                                semanticLabel:
                                    value.metadata?.name ?? value.item.name,
                                url: value.imageUrl,
                                size: 42,
                                fallback: Icons.inventory_2_outlined,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${value.metadata?.totalPrice ?? '—'}',
                                style: const TextStyle(
                                  color: CoachColors.secondaryText,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}
