import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/app/godsense_app.dart';
import 'package:godsense/application/native_speech_controller.dart';
import 'package:godsense/domain/native_speech_settings.dart';
import 'package:godsense/infrastructure/speech/shared_preferences_speech_settings_repository.dart';
import 'package:godsense/presentation/native_speech_settings_card.dart';

class _InstalledSpeechController extends NativeSpeechController {
  _InstalledSpeechController()
    : super(repository: SharedPreferencesSpeechSettingsRepository()) {
    state = const NativeSpeechState(
      loading: false,
      modelsChecked: true,
      speechModelInstalled: true,
      ttsModelInstalled: true,
    );
  }

  @override
  Future<void> updateSettings(NativeSpeechSettings next) async {
    state = state.copyWith(settings: next);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final fonts = FontLoader('InterVariable')
      ..addFont(rootBundle.load('assets/fonts/inter/InterVariable.ttf'))
      ..addFont(rootBundle.load('assets/fonts/inter/InterVariable-Italic.ttf'));
    await fonts.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  test('theme uses variable optical sizes without overriding weight', () {
    final text = godsenseTheme().textTheme;
    for (final style in [
      text.displayLarge!,
      text.displayMedium!,
      text.displaySmall!,
      text.headlineLarge!,
      text.headlineMedium!,
      text.headlineSmall!,
      text.titleLarge!,
      text.titleMedium!,
      text.titleSmall!,
      text.bodyLarge!,
      text.bodyMedium!,
      text.bodySmall!,
      text.labelLarge!,
      text.labelMedium!,
      text.labelSmall!,
    ]) {
      expect(style.fontFamily, 'InterVariable');
      expect(style.fontVariations, [
        ui.FontVariation.opticalSize(style.fontSize!.clamp(14.0, 32.0)),
      ]);
    }
  });

  for (final config in [(672.0, 1.0), (520.0, 1.5), (1000.0, 2.0)]) {
    testWidgets(
      'voice settings readable at width ${config.$1}, scale ${config.$2}',
      (tester) async {
        tester.view.physicalSize = Size(config.$1, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              nativeSpeechProvider.overrideWith(
                (ref) => _InstalledSpeechController(),
              ),
            ],
            child: MaterialApp(
              theme: godsenseTheme(),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(config.$2)),
                child: Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: RepaintBoundary(
                      key: boundaryKey,
                      child: const NativeSpeechSettingsCard(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final dropdowns = tester.widgetList<DropdownButton<String>>(
          find.byType(DropdownButton<String>),
        );
        expect(dropdowns, hasLength(5));
        for (final dropdown in dropdowns) {
          expect(dropdown.style!.fontFamily, 'InterVariable');
          expect(dropdown.style!.fontSize, 14);
          expect(dropdown.style!.fontVariations, const [
            ui.FontVariation.opticalSize(14),
          ]);
        }
        expect(find.text('Instalado'), findsOneWidget);
        expect(find.textContaining('Descargar voz'), findsNothing);
        final capturePath = Platform.environment['GODSENSE_TYPOGRAPHY_CAPTURE'];
        if (config.$2 == 1 && capturePath != null) {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(capturePath).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.tap(find.byType(DropdownButton<String>).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('F8').last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
