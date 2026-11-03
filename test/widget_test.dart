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

  for (final viewport in [
    (360.0, 1.0),
    (672.0, 1.5),
    (1000.0, 2.0),
    (1440.0, 1.0),
    (1920.0, 1.0),
  ]) {
    testWidgets('all feature pages reflow at $viewport', (tester) async {
      tester.view.physicalSize = Size(viewport.$1, 1100);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = viewport.$2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GodSenseHome)),
        listen: false,
      );
      for (var page = 0; page < 6; page++) {
        container.read(selectedPageProvider.notifier).state = page;
        // Busy indicators are valid UI states and deliberately never settle.
        // Render a complete frame without waiting for network/model completion.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(
          tester.takeException(),
          isNull,
          reason: 'page $page at $viewport',
        );
        final scrolling = find
            .descendant(
              of: find.byType(GsFeaturePage).hitTestable(),
              matching: find.byType(Scrollable),
            )
            .first;
        expect(tester.getRect(scrolling).right, viewport.$1);
        expect(tester.getRect(scrolling).left, 0);
        for (var step = 0; step < 3; step++) {
          await tester.drag(scrolling, const Offset(0, -450));
          await tester.pump(const Duration(milliseconds: 350));
          expect(
            tester.takeException(),
            isNull,
            reason: 'scroll page $page at $viewport',
          );
        }
      }
    });
  }

  testWidgets('readiness cards open the section that resolves their state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alertas del minimapa'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(GodSenseHome)),
      listen: false,
    );
    expect(container.read(selectedPageProvider), 2);
    expect(find.text('Mapa y alertas'), findsNothing);
    expect(find.text('Estado de las alertas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact title bar keeps navigation and HUD actions accessible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    var edits = 0;
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: godsenseTheme(),
        home: Scaffold(
          body: Column(
            children: [
              GodSenseTitleBar(
                selectedPage: 0,
                onSelectPage: (value) => selected = value,
                overlayEditing: false,
                onToggleEditing: () => edits++,
                onResetPanels: null,
                onHelp: () {},
                sessionLabel: 'Sin partida',
                isOnline: false,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Acciones de GodSense'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar HUD'));
    await tester.pumpAndSettle();
    expect(edits, 1);
    await Scrollable.ensureVisible(
      tester.element(find.byTooltip('Ajustes')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ajustes'));
    await tester.pump();
    expect(selected, 5);
    expect(tester.takeException(), isNull);
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
      final owlSlot = tester.getRect(
        find.byKey(const Key('titlebar-owl-slot')),
      );
      final owl = tester.getRect(find.byKey(const Key('titlebar-owl')));
      final titleBar = tester.getRect(find.byType(GodSenseTitleBar));
      expect(owlSlot.bottom, titleBar.bottom);
      expect(owl.bottom, closeTo(titleBar.bottom + 5, .1));
      expect(owl.width, 48);
      expect(owl.top, greaterThan(titleBar.top));
      expect(
        find.ancestor(
          of: find.byKey(const Key('titlebar-owl')),
          matching: find.byType(ClipRect),
        ),
        findsAtLeastNWidgets(1),
      );
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
        GsColors.accentTint,
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
        GsColors.dangerAction,
      );
      final titleBarDragSurface = find.ancestor(
        of: find.byTooltip('Scout'),
        matching: find.byWidgetPredicate(
          (widget) => widget is GestureDetector && widget.onPanStart != null,
        ),
      );
      expect(titleBarDragSurface, findsNothing);
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
    expect(find.text('Estado de las alertas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final setup in [(360.0, 1.5), (1280.0, 1.0)]) {
    testWidgets(
      'settings separate tasks and keep actions reachable at $setup',
      (tester) async {
        tester.view.devicePixelRatio = 1.25;
        tester.view.physicalSize = Size(setup.$1 * 1.25, 1000 * 1.25);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(setup.$2)),
            child: _testApp(),
          ),
        );
        await tester.ensureVisible(find.byTooltip('Ajustes'));
        await tester.pump();
        await tester.tap(find.byTooltip('Ajustes'));
        await tester.pump();
        expect(find.text('Juego y HUD'), findsOneWidget);
        expect(find.text('Voz y micrófono'), findsOneWidget);
        expect(find.text('IA del coach'), findsOneWidget);
        expect(find.text('Datos y privacidad'), findsOneWidget);
        expect(find.text('Exportar mis datos'), findsNothing);
        await tester.tap(find.text('Voz y micrófono'));
        await tester.pump();
        expect(find.text('Tu micrófono'), findsOneWidget);
        expect(find.text('Borrar datos locales'), findsNothing);
        await tester.tap(find.text('Datos y privacidad'));
        await tester.pump();
        final scroll = find
            .descendant(
              of: find.byType(SettingsPage),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.text('Borrar datos locales'),
          200,
          scrollable: scroll,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Borrar datos locales'));
        await tester.pumpAndSettle();
        expect(find.text('¿Borrar los datos locales?'), findsOneWidget);
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(find.text('¿Borrar los datos locales?'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'manual minimap settings explain units and reject invalid dimensions',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 1000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_testApp());
      await tester.tap(find.byTooltip('Ajustes'));
      await tester.pump();
      await tester.ensureVisible(find.text('Ajustar coordenadas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajustar coordenadas'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Coordenadas en píxeles de pantalla'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextFormField).at(2), '0');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Debe ser mayor que cero.'), findsOneWidget);
      expect(find.text('Calibración manual'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Calibración manual'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

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
    await tester.tap(find.text('Voz y micrófono'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Tu micrófono'),
      400,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.text('Tu micrófono'), findsOneWidget);
    expect(find.text('Hablar con el coach'), findsOneWidget);
    expect(find.text('Opciones avanzadas de voz'), findsOneWidget);
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
