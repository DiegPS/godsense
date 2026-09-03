import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/app/godsense_app.dart';

void main() {
  for (final width in [620.0, 1100.0]) {
    testWidgets('coaching settings preview adapts at $width px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: godsenseTheme(),
            home: const Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: CoachingSettingsSection(),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Proveedor del coach'), findsOneWidget);
      expect(find.text('OpenCode'), findsOneWidget);
      expect(find.text('Kilo Code'), findsOneWidget);
      expect(find.text('Modelo y respuestas'), findsOneWidget);
      expect(find.text('Contexto y privacidad'), findsOneWidget);
      expect(find.text('Por conectar'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  }
}
