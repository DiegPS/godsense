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
      subtitle: 'Builds y rutas de compra optimizadas para tu rol.',
      icon: Icons.inventory_2_outlined,
      action: Semantics(
        button: true,
        label: 'Importar set de objetos en League',
        child: OutlinedButton.icon(
          onPressed: groups.isEmpty || importing ? null : onImport,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(32, 30),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            side: const BorderSide(color: Color(0x3338BDF8)),
            backgroundColor: const Color(0x1438BDF8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          icon: importing
              ? const SizedBox.square(
                  dimension: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                )
              : const Icon(Icons.download_outlined, size: 14, color: Color(0xFF38BDF8)),
          label: const Text(
            'Importar',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF38BDF8),
            ),
          ),
        ),
      ),
      child: groups.isEmpty
          ? const CoachEmptyState(
              message: 'Esperando recomendaciones para campeón y posición.',
              icon: Icons.inventory_2_outlined,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < groups.length; i++) ...[
                  _ItemGroupSection(group: groups[i]),
                  if (i != groups.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

class _ItemGroupSection extends StatelessWidget {
  const _ItemGroupSection({required this.group});

  final RecommendedItemGroupViewData group;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1017),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                group.title.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in group.items)
                Tooltip(
                  message:
                      '${value.metadata?.name ?? value.item.name}\n'
                      '${value.metadata?.totalPrice ?? 0} de oro\n'
                      '${value.metadata?.description ?? 'Metadatos pendientes'}',
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0x1FFFFFFF)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: AssetPortrait(
                            semanticLabel:
                                value.metadata?.name ?? value.item.name,
                            url: value.imageUrl,
                            size: 38,
                            fallback: Icons.inventory_2_outlined,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.monetization_on_outlined,
                              size: 10,
                              color: Color(0xFFFBBF24),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${value.metadata?.totalPrice ?? '—'}',
                              style: const TextStyle(
                                color: Color(0xFFFBBF24),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
