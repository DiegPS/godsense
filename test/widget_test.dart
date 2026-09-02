import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/companion_controller.dart';
import 'package:godsense/application/dependencies.dart';
import 'package:godsense/application/native_league_controller.dart';
import 'package:godsense/infrastructure/native_runtime/native_companion_gateway.dart';
import 'package:godsense/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'godsense.getting_started.v1.seen': true,
    }),
  );

  testWidgets('shows the GodSense overview', (tester) async {
    await tester.pumpWidget(_testApp());

    expect(
      find.textContaining(RegExp('GodSense', caseSensitive: false)),
      findsAtLeastNWidgets(1),
    );
    expect(find.text('League client'), findsOneWidget);
    expect(find.text('Vision tracker'), findsOneWidget);
  });

  testWidgets('uses Flutter native navigation with labeled destinations', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp());

    final navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigation.destinations, hasLength(6));
    expect(
      navigation.destinations.whereType<NavigationDestination>().map(
        (destination) => destination.label,
      ),
      everyElement(isNotEmpty),
    );
  });

  testWidgets('uses only the native DartCV vision runtime', (tester) async {
    await tester.pumpWidget(_testApp());

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pumpAndSettle();
    expect(find.text('DartCV tracker nativo'), findsOneWidget);
    expect(find.text('Python backend'), findsNothing);
  });

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
      nativeLeagueProvider.overrideWith((_) => NativeLeagueController()),
      companionControllerProvider.overrideWith(
        (_) => CompanionController(
          NativeCompanionGateway(),
          runtime: const InProcessCompanionRuntime(),
          coach: const NativeCoachHealthGateway(),
          coachRuntime: const InProcessCompanionRuntime(),
        ),
      ),
    ],
    child: const GodSenseApp(),
  );
}
