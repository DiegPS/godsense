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
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());

    expect(
      find.textContaining(RegExp('GodSense', caseSensitive: false)),
      findsAtLeastNWidgets(1),
    );
    expect(find.text('Cliente de League'), findsOneWidget);
    expect(find.text('Alertas del minimapa'), findsOneWidget);
  });

  testWidgets('keeps navigation and window controls in one top bar', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [1280.0, 900.0]) {
      tester.view.physicalSize = Size(width, 800);
      await tester.pumpWidget(_testApp());
      await tester.pump();
      final brandY = tester.getCenter(find.text('GodSense')).dy;
      for (final label in [
        'Inicio',
        'En vivo',
        'Mapa',
        'Coach',
        'Scout',
        'Ajustes',
      ]) {
        final tab = find.byTooltip(label);
        expect(tab, findsOneWidget);
        expect(tester.getCenter(tab).dy, closeTo(brandY, 1));
      }
      expect(tester.getCenter(find.text('Editar HUD')).dy, closeTo(brandY, 1));
      expect(tester.getCenter(find.byTooltip('Cerrar')).dy, closeTo(brandY, 1));
      final startButton = tester.widget<TextButton>(
        find.descendant(
          of: find.byTooltip('Inicio'),
          matching: find.byType(TextButton),
        ),
      );
      expect(
        startButton.style?.backgroundColor?.resolve(const {}),
        Colors.transparent,
      );
      expect(
        startButton.style?.backgroundColor?.resolve({WidgetState.hovered}),
        GsColors.cyanGlow,
      );
      final closeButton = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('Cerrar'),
          matching: find.byType(IconButton),
        ),
      );
      expect(
        closeButton.style?.backgroundColor?.resolve(const {}),
        Colors.transparent,
      );
      expect(
        closeButton.style?.backgroundColor?.resolve({WidgetState.hovered}),
        GsColors.crimson,
      );
      final titleBarDragSurface = find.ancestor(
        of: find.byTooltip('Scout'),
        matching: find.byWidgetPredicate(
          (widget) => widget is GestureDetector && widget.onPanStart != null,
        ),
      );
      expect(titleBarDragSurface, findsOneWidget);
      expect(
        find.text(
          'Tu cuenta, la partida actual y todo lo que requiere atención.',
        ),
        findsNothing,
      );
    }
    await tester.tap(find.byTooltip('Mapa'));
    await tester.pump();
    expect(find.text('Estado de las alertas'), findsOneWidget);
    expect(find.text('Mapa y alertas'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses only the native DartCV vision runtime', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());

    await tester.tap(find.byTooltip('Mapa'));
    await tester.pump();
    expect(find.text('Estado de las alertas'), findsOneWidget);
    expect(find.text('Python backend'), findsNothing);
  });

  testWidgets('exposes native Sherpa Push-to-Talk and voice models', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());

    await tester.tap(find.byTooltip('Ajustes'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Voz y atajo para hablar'),
      400,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.text('Voz y atajo para hablar'), findsOneWidget);
    expect(find.text('Hablar con el coach'), findsOneWidget);
    expect(find.text('Tipo de voz'), findsOneWidget);
  });
}

Widget _testApp() {
  return ProviderScope(
    overrides: [
      nativeLeagueProvider.overrideWith((_) => NativeLeagueController()),
      companionControllerProvider.overrideWith(
        (_) => CompanionController(NativeCompanionGateway()),
      ),
    ],
    child: const GodSenseApp(),
  );
}
