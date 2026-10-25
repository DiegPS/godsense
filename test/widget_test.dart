import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/companion_controller.dart';
import 'package:godsense/application/dependencies.dart';
import 'package:godsense/application/native_league_controller.dart';
import 'package:godsense/application/native_speech_controller.dart';
import 'package:godsense/infrastructure/speech/shared_preferences_speech_settings_repository.dart';
import 'package:godsense/application/overlay_layout_controller.dart';
import 'package:godsense/application/overlay_visibility_controller.dart';
import 'package:godsense/infrastructure/native_runtime/native_companion_gateway.dart';
import 'package:godsense/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'godsense.getting_started.v1.seen': true,
    }),
  );

  test(
    'disabled overlay can be edited without enabling it for games',
    () async {
      final layout = OverlayLayoutController();
      await layout.load();
      final visibility = OverlayVisibilityController();
      await visibility.load();
      await visibility.setEnabled(false);
      final container = ProviderContainer(
        overrides: [
          overlayLayoutProvider.overrideWith((_) => layout),
          overlayEnabledProvider.overrideWith((_) => visibility),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(overlayWindowVisibleProvider), isFalse);
      layout.setEditing(true);
      expect(container.read(overlayWindowVisibleProvider), isTrue);
      expect(container.read(overlayEnabledProvider), isFalse);
      layout.setEditing(false);
      expect(container.read(overlayWindowVisibleProvider), isFalse);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          OverlayVisibilityController.storageKey,
        ),
        isFalse,
      );
    },
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

  testWidgets(
    'a response can be stopped from the title bar at minimum window width',
    (tester) async {
      tester.view.physicalSize = const Size(900, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final speech = _SpeakingSpeech();
      await tester.pumpWidget(_testApp(speech: speech));
      await tester.tap(find.byTooltip('Detener voz'));
      await tester.pump();
      expect(speech.stops, 1);
      expect(find.byTooltip('Detener voz'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the HUD reset button preserves the layout until confirmed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final layout = OverlayLayoutController();
    await layout.load();
    final original = layout.state.panels['gank']!;
    layout.move('gank', const Offset(100, 20), const Size(1280, 900));
    final moved = layout.state.panels['gank']!;
    layout.setEditing(true);
    await tester.pumpWidget(_testApp(layout: layout));
    await tester.tap(find.byTooltip('Restablecer HUD'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(layout.state.panels['gank'], same(moved));
    await tester.tap(find.byTooltip('Restablecer HUD'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restablecer'));
    await tester.pumpAndSettle();
    expect(layout.state.panels['gank']!.x, original.x);
    expect(layout.state.panels['gank']!.y, original.y);
    expect(tester.takeException(), isNull);
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

  testWidgets(
    'settings persist the overlay toggle and describe the real UI language',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_testApp());
      await tester.tap(find.byTooltip('Ajustes'));
      await tester.pump();
      expect(find.text('Idioma de la interfaz'), findsOneWidget);
      expect(find.text('Idioma del asistente'), findsNothing);
      final toggle = find.ancestor(
        of: find.text('Mostrar el overlay durante la partida'),
        matching: find.byType(SwitchListTile),
      );
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
      await tester.tap(find.text('Mostrar el overlay durante la partida'));
      await tester.pump();
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          OverlayVisibilityController.storageKey,
        ),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _testApp({
  OverlayLayoutController? layout,
  NativeSpeechController? speech,
}) {
  return ProviderScope(
    overrides: [
      if (speech != null) nativeSpeechProvider.overrideWith((_) => speech),
      if (layout != null) overlayLayoutProvider.overrideWith((_) => layout),
      nativeLeagueProvider.overrideWith((_) => NativeLeagueController()),
      companionControllerProvider.overrideWith(
        (_) => CompanionController(NativeCompanionGateway()),
      ),
    ],
    child: const GodSenseApp(),
  );
}

class _SpeakingSpeech extends NativeSpeechController {
  _SpeakingSpeech()
    : super(repository: SharedPreferencesSpeechSettingsRepository()) {
    state = const NativeSpeechState(loading: false, ttsBusy: true);
  }
  int stops = 0;
  @override
  Future<void> stopSpeaking() async {
    stops++;
    state = state.copyWith(ttsBusy: false);
  }
}
