import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/presentation/shared/getting_started_guide.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('first launch routes to settings and persists acknowledgement', (
    tester,
  ) async {
    int? destination;
    await tester.pumpWidget(
      MaterialApp(
        home: GettingStartedGate(
          onDestination: (value) => destination = value,
          child: const Scaffold(body: Text('Home')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Primeros pasos con GodSense'), findsOneWidget);
    await tester.tap(find.text('Configurar voz'));
    await tester.pumpAndSettle();
    expect(destination, 5);
    expect(
      (await SharedPreferences.getInstance()).getBool(gettingStartedSeenKey),
      isTrue,
    );
  });

  testWidgets('does not interrupt returning users', (tester) async {
    SharedPreferences.setMockInitialValues({gettingStartedSeenKey: true});
    await tester.pumpWidget(
      MaterialApp(
        home: GettingStartedGate(
          onDestination: (_) {},
          child: const Scaffold(body: Text('Home')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Primeros pasos con GodSense'), findsNothing);
  });

  testWidgets('guide remains scrollable with large text and narrow width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showGettingStartedGuide(context),
                child: const Text('Help'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Help'));
    await tester.pumpAndSettle();
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
