import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../../app/godsense_theme.dart';
import 'godsense_ui_components.dart';

@Preview(name: 'Controles y superficies', size: Size(1000, 650))
Widget designSystemPreview() => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: godsenseTheme(),
  home: Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          const GsSectionHeading(
            page: true,
            title: 'Tu próxima mejor partida',
            subtitle: 'Una experiencia coherente, desde la preparación hasta el análisis.',
          ),
          const SizedBox(height: 24),
          GsCard(
            title: 'Controles',
            subtitle: 'Una misma altura. Foco visible. Estados claros.',
            icon: Icons.tune_rounded,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                const GsInput(
                  width: 200,
                  hintText: 'Buscar jugador',
                  prefixIcon: Icons.search,
                ),
                GsSelect(
                  width: 160,
                  value: 'es',
                  items: const {'es': 'Español'},
                  onChanged: (_) {},
                ),
                GsButton(label: 'Buscar', onPressed: () {}),
                GsButton(
                  label: 'Secundario',
                  variant: GsButtonVariant.secondary,
                  onPressed: () {},
                ),
                const GsButton(label: 'Actualizando', loading: true),
                const GsButton(label: 'No disponible'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const GsCard(
            title: 'Estados',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                GsBadge(label: 'Conectado', variant: GsBadgeVariant.success),
                GsBadge(
                  label: 'Requiere atención',
                  variant: GsBadgeVariant.warning,
                ),
                GsBadge(
                  label: 'No se pudo conectar',
                  variant: GsBadgeVariant.danger,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);
