import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/companion_controller.dart';
import 'package:godsense/application/dependencies.dart';
import 'package:godsense/infrastructure/legacy/legacy_companion_gateway.dart';
import 'package:godsense/infrastructure/local_coach/local_coach_gateway.dart';
import 'package:godsense/main.dart';

void main() {
  testWidgets('shows the GodSense overview', (tester) async {
    await tester.pumpWidget(_testApp());

    expect(find.text('GodSense'), findsOneWidget);
    expect(find.text('League client'), findsOneWidget);
    expect(find.text('Vision tracker'), findsOneWidget);
  });

  testWidgets(
    'defaults to native vision and keeps Python diagnostics optional',
    (tester) async {
      await tester.pumpWidget(_testApp());

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();
      expect(find.text('DartCV tracker selected'), findsOneWidget);

      await tester.tap(find.text('Python backend'));
      await tester.pumpAndSettle();
      expect(find.text('Python tracker selected'), findsOneWidget);
    },
  );

  testWidgets('exposes native Sherpa Push-to-Talk and voice models', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp());

    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Voz local · Sherpa-ONNX'),
      400,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.text('Voz local · Sherpa-ONNX'), findsOneWidget);
    expect(find.text('Push-to-Talk local'), findsOneWidget);
    expect(find.text('Modelo TTS'), findsOneWidget);
  });
}

Widget _testApp() {
  return ProviderScope(
    overrides: [
      companionControllerProvider.overrideWith(
        (_) => CompanionController(
          LegacyCompanionGateway(),
          runtime: LegacyCompanionRuntime(),
          coach: LocalCoachGateway(),
          coachRuntime: LocalCoachRuntime(),
        ),
      ),
    ],
    child: const GodSenseApp(),
  );
}
