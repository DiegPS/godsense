import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/app/godsense_theme.dart';
import 'package:godsense/presentation/shared/godsense_ui_components.dart';

void main() {
  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('controls align at text scale $scale', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: godsenseTheme(),
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Wrap(
                spacing: 8,
                children: [
                  GsButton(
                    key: const Key('button'),
                    label: 'Buscar',
                    onPressed: () {},
                  ),
                  const GsInput(
                    key: Key('input'),
                    width: 160,
                    hintText: 'Jugador',
                  ),
                  GsSelect(
                    key: const Key('select'),
                    width: 160,
                    value: 'es',
                    items: const {'es': 'Español'},
                    onChanged: (_) {},
                  ),
                  GsIconButton(
                    key: const Key('icon'),
                    icon: Icons.search,
                    tooltip: 'Buscar',
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final heights = [
        'button',
        'input',
        'select',
        'icon',
      ].map((key) => tester.getSize(find.byKey(Key(key))).height).toList();
      for (final height in heights) {
        expect(height, closeTo(heights.first, .1));
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('button supports keyboard and keeps width while loading', (
    tester,
  ) async {
    var calls = 0;
    Widget app(bool loading) => MaterialApp(
      theme: godsenseTheme(),
      home: Scaffold(
        body: GsButton(
          label: 'Actualizar perfil',
          loading: loading,
          onPressed: () => calls++,
        ),
      ),
    );
    await tester.pumpWidget(app(false));
    final before = tester.getSize(find.byType(GsButton));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(calls, 1);
    await tester.pumpWidget(app(true));
    expect(tester.getSize(find.byType(GsButton)), before);
    await tester.tap(find.byType(GsButton));
    expect(calls, 1);
  });
}
