import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/coach_controller.dart';
import 'package:godsense/domain/assets/game_asset_catalog.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/domain/league/item_recommendation.dart';
import 'package:godsense/domain/league/rune_recommendation.dart';
import 'package:godsense/presentation/coach/setup/item_bundles_view.dart';
import 'package:godsense/presentation/coach/setup/rune_tree_view.dart';

void main() {
  final provenance = AssetProvenance(
    source: GameAssetSource.dataDragon,
    sourceVersion: '16.17.1',
    locale: LeagueLocale('es_MX'),
    contentHash: 'synthetic',
  );
  RuneRecommendationViewData variant(String id, {bool metadata = true}) =>
      RuneRecommendationViewData(
        variant: RuneRecommendationVariant(
          recommendationId: id,
          championId: 103,
          position: LeaguePosition.middle,
          perkIds: const [8112, 8139, 5008],
          primaryStyleId: 8100,
          secondaryStyleId: 8200,
          summonerSpellIds: const [4, 14],
          keystoneId: 8112,
          primaryAttribute: 'Dominación',
          secondaryAttribute: 'Brujería',
          isDefaultPosition: true,
          isOverride: false,
        ),
        runes: [
          RuneAssetViewData(
            id: 8112,
            metadata: metadata
                ? RuneMetadata(
                    id: 8112,
                    name: 'Electrocutar',
                    styleId: 8100,
                    slot: 0,
                    isKeystone: true,
                    iconPath: '',
                    description: 'Tres golpes activan daño adicional.',
                    provenance: provenance,
                  )
                : null,
          ),
          const RuneAssetViewData(id: 5008),
        ],
        spells: [
          SpellAssetViewData(
            id: 4,
            metadata: metadata
                ? SummonerSpellMetadata(
                    id: 4,
                    name: 'Destello',
                    description: 'Reposiciona al campeón.',
                    iconPath: '',
                    provenance: provenance,
                  )
                : null,
          ),
          const SpellAssetViewData(id: 14),
        ],
      );
  final groups = [
    RecommendedItemGroupViewData(
      title: 'Inicio 1',
      items: [
        RecommendedItemViewData(
          item: const RecommendedItem(id: 1056, name: 'Anillo'),
          metadata: ItemMetadata(
            id: 1056,
            name: 'Anillo de Doran',
            description: 'Inicio de línea.',
            totalPrice: 400,
            basePrice: 400,
            iconPath: '',
            provenance: provenance,
          ),
        ),
      ],
    ),
    const RecommendedItemGroupViewData(
      title: 'Compra 2 · hasta 4 objetos completos',
      items: [
        RecommendedItemViewData(item: RecommendedItem(id: 3020, name: 'Botas')),
      ],
    ),
  ];
  Widget wrap(Widget child, {double width = 700, double scale = 1}) =>
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(width: width, child: child),
              ),
            ),
          ),
        ),
      );

  testWidgets(
    'rune import chooses the requested variant and disables repeats while importing',
    (tester) async {
      final imported = <String>[];
      final variants = [variant('first'), variant('second', metadata: false)];
      Widget view(bool importing) => wrap(
        RuneTreeView(
          variants: variants,
          importing: importing,
          onImport: (value) => imported.add(value.variant.recommendationId),
        ),
      );
      await tester.pumpWidget(view(false));
      expect(find.text('Variante 1 · Electrocutar'), findsOneWidget);
      expect(find.text('Variante 2 · Keystone 8112'), findsOneWidget);
      expect(
        find.byTooltip('Electrocutar\nTres golpes activan daño adicional.'),
        findsOneWidget,
      );
      expect(find.byTooltip('Hechizo 14\n'), findsNWidgets(2));
      await tester.tap(find.byTooltip('Importar variante 2 en League'));
      expect(imported, ['second']);
      await tester.pumpWidget(view(true));
      for (final index in [1, 2]) {
        final button = tester.widget<IconButton>(
          find.ancestor(
            of: find.byTooltip('Importar variante $index en League'),
            matching: find.byType(IconButton),
          ),
        );
        expect(button.onPressed, isNull);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'runes explain an empty recommendation without offering an import',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          RuneTreeView(
            variants: const [],
            importing: false,
            onImport: (_) => fail('Empty recommendations cannot be imported'),
          ),
        ),
      );
      expect(
        find.text('Selecciona campeón y posición para cargar runas.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.download_outlined), findsNothing);
    },
  );

  testWidgets(
    'item set import is unavailable until recommendations exist and during import',
    (tester) async {
      var imports = 0;
      Widget view(List<RecommendedItemGroupViewData> values, bool importing) =>
          wrap(
            ItemBundlesView(
              groups: values,
              importing: importing,
              onImport: () => imports++,
            ),
          );
      await tester.pumpWidget(view(const [], false));
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      await tester.pumpWidget(view(groups, false));
      expect(find.text('400'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      expect(
        find.byTooltip('Anillo de Doran\n400 de oro\nInicio de línea.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Importar'));
      expect(imports, 1);
      await tester.pumpWidget(view(groups, true));
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [350.0, 700.0]) {
    testWidgets('recommendations fit width $width with text at 200 percent', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          Column(
            children: [
              RuneTreeView(
                variants: [variant('large')],
                importing: false,
                onImport: (_) {},
              ),
              ItemBundlesView(
                groups: groups,
                importing: false,
                onImport: () {},
              ),
            ],
          ),
          width: width,
          scale: 2,
        ),
      );
      expect(find.text('Variante 1 · Electrocutar'), findsOneWidget);
      expect(find.text('COMPRA 2 · HASTA 4 OBJETOS COMPLETOS'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
