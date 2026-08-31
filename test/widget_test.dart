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

  testWidgets('switches between vision tracker implementations', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp());

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Python tracker selected'), findsOneWidget);

    await tester.tap(find.text('DartCV native'));
    await tester.pumpAndSettle();
    expect(find.text('DartCV tracker selected'), findsOneWidget);
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
