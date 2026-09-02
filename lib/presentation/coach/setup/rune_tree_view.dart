import 'package:flutter/material.dart';

import '../../../application/coach_controller.dart';
import '../shared/asset_portrait.dart';
import '../shared/coach_surface.dart';

class RuneTreeView extends StatelessWidget {
  const RuneTreeView({
    super.key,
    required this.variants,
    required this.importing,
    required this.onImport,
  });

  final List<RuneRecommendationViewData> variants;
  final bool importing;
  final ValueChanged<RuneRecommendationViewData> onImport;

  @override
  Widget build(BuildContext context) {
    return CoachSurface(
      title: 'Runas y hechizos de Riot',
      icon: Icons.auto_fix_high_outlined,
      child: variants.isEmpty
          ? const CoachEmptyState(
              message: 'Selecciona campeón y posición para cargar runas.',
            )
          : Column(
              children: [
                for (var index = 0; index < variants.length; index++)
                  _Variant(
                    index: index,
                    value: variants[index],
                    importing: importing,
                    onImport: () => onImport(variants[index]),
                  ),
              ],
            ),
    );
  }
}

class _Variant extends StatelessWidget {
  const _Variant({
    required this.index,
    required this.value,
    required this.importing,
    required this.onImport,
  });

  final int index;
  final RuneRecommendationViewData value;
  final bool importing;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final keystone = value.runes
        .where((rune) => rune.metadata?.isKeystone == true)
        .firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CoachColors.elevated,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AssetPortrait(
                    semanticLabel:
                        keystone?.metadata?.name ??
                        'Keystone ${value.variant.keystoneId}',
                    url: keystone?.imageUrl,
                    size: 48,
                    circular: true,
                    fallback: Icons.bolt_outlined,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Variante ${index + 1} · '
                          '${keystone?.metadata?.name ?? 'Keystone ${value.variant.keystoneId}'}',
                          style: const TextStyle(
                            color: CoachColors.primaryText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${value.variant.position.lcuValue} · '
                          '${value.variant.primaryAttribute} / '
                          '${value.variant.secondaryAttribute}',
                          style: const TextStyle(
                            color: CoachColors.secondaryText,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Importar variante ${index + 1} en League',
                    onPressed: importing ? null : onImport,
                    icon: const Icon(Icons.download_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final rune in value.runes)
                    Tooltip(
                      message:
                          '${rune.metadata?.name ?? 'Runa ${rune.id}'}\n'
                          '${rune.metadata?.description ?? 'Metadatos pendientes'}',
                      child: AssetPortrait(
                        semanticLabel: rune.metadata?.name ?? 'Runa ${rune.id}',
                        url: rune.imageUrl,
                        size: rune.metadata?.isKeystone == true ? 38 : 30,
                        circular: true,
                        fallback: Icons.circle_outlined,
                      ),
                    ),
                  const SizedBox(width: 6),
                  for (final spell in value.spells)
                    Tooltip(
                      message:
                          '${spell.metadata?.name ?? 'Hechizo ${spell.id}'}\n'
                          '${spell.metadata?.description ?? ''}',
                      child: AssetPortrait(
                        semanticLabel:
                            spell.metadata?.name ?? 'Hechizo ${spell.id}',
                        url: spell.imageUrl,
                        size: 34,
                        fallback: Icons.flash_on_outlined,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
