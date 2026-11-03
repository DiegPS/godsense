import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_consistent_ui/flutter_consistent_ui.dart';
import 'package:godsense/app/godsense_theme.dart';
import 'package:godsense/presentation/shared/godsense_ui_components.dart';

Rect _border(WidgetTester tester, String key) {
  final decorator = find.descendant(
    of: find.byKey(Key(key)),
    matching: find.byType(InputDecorator),
  );
  final text = find
      .descendant(of: decorator, matching: find.byType(Text))
      .first;
  final box = InputDecorator.containerOf(tester.element(text))!;
  return box.localToGlobal(Offset.zero) & box.size;
}

double _buttonSurface(WidgetTester tester) => tester
    .getSize(
      find
          .descendant(
            of: find.byType(TextButton),
            matching: find.byType(Material),
          )
          .first,
    )
    .height;

void main() {
  test('GodSense installs library geometry without replacing its identity', () {
    final theme = godsenseTheme();
    expect(theme.extension<UiThemeData>(), GsSizes.geometry);
    expect(theme.extension<UiBorderTheme>()!.focusedWidth, 2);
    expect(theme.inputDecorationTheme.focusedBorder!.borderSide.width, 2);
    expect(theme.inputDecorationTheme.focusedErrorBorder!.borderSide.width, 2);
    expect(theme.extension<UiSurfaceStyle>()!.border!.color, GsColors.border);
    expect(theme.brightness, Brightness.light);
    expect(theme.colorScheme.primary, GsColors.accent);
    expect(theme.scaffoldBackgroundColor, GsColors.canvas);
    expect(theme.textTheme.bodyMedium!.fontFamily, 'InterVariable');
    expect(theme.inputDecorationTheme.constraints, isNull);
  });

  for (final viewport in [(360.0, 1.0), (1440.0, 1.25)]) {
    for (final scale in [1.0, 1.5, 2.0, 3.0]) {
      testWidgets('painted controls align at $viewport, text $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(viewport.$1, 2000) * viewport.$2;
        tester.view.devicePixelRatio = viewport.$2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        late double expectedHeight;
        await tester.pumpWidget(
          MaterialApp(
            theme: godsenseTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  expectedHeight = UiControlMetrics.height(context);
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: UiFormFields(
                      children: [
                        const GsInput(
                          key: Key('input'),
                          labelText: 'Jugador',
                          helperText: 'Nombre de Riot, sin perder la captura.',
                          prefixIcon: Icons.person_outline,
                        ),
                        GsSelect<String>(
                          key: const Key('select'),
                          value: 'es',
                          items: const {'es': 'Español'},
                          helperText: 'Idioma del asistente.',
                          onChanged: (_) {},
                        ),
                        GsButton(label: 'Buscar', onPressed: () {}),
                        GsIconButton(icon: Icons.search, onPressed: () {}),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final key in ['input', 'select']) {
          expect(_border(tester, key).height, closeTo(expectedHeight, .6));
        }
        expect(_buttonSurface(tester), closeTo(expectedHeight, .6));
        expect(
          tester.getSize(find.byType(GsIconButton)).height,
          closeTo(expectedHeight, .6),
        );
        expect(
          tester.getBottomLeft(find.byKey(const Key('input'))).dy,
          lessThan(tester.getTopLeft(find.byKey(const Key('select'))).dy),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('large fields preserve their border and natural helper space', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: godsenseTheme(),
        home: const Scaffold(
          body: GsInput(
            key: Key('input'),
            height: 48,
            labelText: 'Jugador',
            helperText: 'Ayuda fuera del borde, no dentro de una altura fija.',
          ),
        ),
      ),
    );
    expect(_border(tester, 'input').height, closeTo(48, .6));
    expect(tester.getSize(find.byType(GsInput)).height, greaterThan(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('validation keeps room below the select instead of clipping', (
    tester,
  ) async {
    final form = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: godsenseTheme(),
        home: Scaffold(
          body: Form(
            key: form,
            child: UiFormFields(
              children: [
                GsSelect<String>(
                  key: const Key('select'),
                  value: 'es',
                  items: const {'es': 'Español'},
                  onChanged: (_) {},
                  validator: (_) =>
                      'Selecciona un idioma disponible para continuar.',
                ),
                const GsInput(key: Key('input'), labelText: 'Siguiente campo'),
              ],
            ),
          ),
        ),
      ),
    );
    expect(form.currentState!.validate(), isFalse);
    await tester.pumpAndSettle();
    expect(_border(tester, 'select').height, closeTo(40, .6));
    expect(
      tester.getSize(find.byKey(const Key('select'))).height,
      greaterThan(40),
    );
    expect(
      tester
          .getBottomLeft(
            find.text('Selecciona un idioma disponible para continuar.'),
          )
          .dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('input'))).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'input retains controller, focus and callbacks through resizing',
    (tester) async {
      final controller = TextEditingController();
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 1000);
      var capture = '';
      await tester.pumpWidget(
        MaterialApp(
          theme: godsenseTheme(),
          home: Scaffold(
            body: GsInput(
              controller: controller,
              focusNode: focus,
              hintText: 'Jugador',
              onChanged: (value) => capture = value,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Jugador#LAN');
      tester.view.physicalSize = const Size(360, 1000);
      await tester.pump();
      expect(controller.text, 'Jugador#LAN');
      expect(capture, 'Jugador#LAN');
      expect(focus.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
