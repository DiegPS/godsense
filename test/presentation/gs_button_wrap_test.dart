import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/app/godsense_app.dart';

void main() {
  testWidgets('GsButton inside Wrap shrinks to fit its content', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            child: Wrap(
              spacing: 8,
              children: [
                GsButton(
                  label: 'Buscar',
                  icon: Icons.search,
                  onPressed: () {},
                ),
                GsButton(
                  label: 'Mi Cuenta',
                  icon: Icons.person,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final buscarButton = tester.getSize(find.byType(GsButton).first);

    // Button should NOT stretch to 800px! It should be compact (e.g. ~100-130px)
    expect(buscarButton.width, lessThan(200));
    expect(buscarButton.height, equals(GsSizes.controlHeight));

    final miCuentaButton = tester.getSize(find.byType(GsButton).last);
    expect(miCuentaButton.width, lessThan(200));
    expect(miCuentaButton.height, equals(GsSizes.controlHeight));
  });

  testWidgets('GsButton compact in speech settings card renders side-by-side without stretching', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                GsButton(
                  label: 'Probar voz',
                  icon: Icons.volume_up_rounded,
                  variant: GsButtonVariant.secondary,
                  compact: true,
                  onPressed: () {},
                ),
                GsButton(
                  label: 'Eliminar voz descargada',
                  icon: Icons.delete_outline_rounded,
                  variant: GsButtonVariant.ghost,
                  compact: true,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final probarVoz = tester.getSize(find.byType(GsButton).first);
    final eliminarVoz = tester.getSize(find.byType(GsButton).last);

    // Both buttons should fit side by side comfortably, not stretch to 800px!
    expect(probarVoz.width, lessThan(200));
    expect(eliminarVoz.width, lessThan(400));
    expect(probarVoz.width + eliminarVoz.width + 8, lessThan(800));

    // Both should be on the same vertical Y position (side by side, not wrapped to separate lines)
    final probarPos = tester.getTopLeft(find.byType(GsButton).first);
    final eliminarPos = tester.getTopLeft(find.byType(GsButton).last);
    expect(probarPos.dy, equals(eliminarPos.dy));
  });

  testWidgets('GsInput, GsButton, and GsIconButton have identical 36px height in search bar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const GsInput(
                  width: 200,
                  hintText: 'Nombre de Riot',
                ),
                const GsInput(
                  width: 90,
                  hintText: 'Tag',
                ),
                GsButton(
                  label: 'Buscar',
                  icon: Icons.search,
                  onPressed: () {},
                ),
                GsButton(
                  label: 'Mi Cuenta',
                  icon: Icons.person,
                  onPressed: () {},
                ),
                GsIconButton(
                  icon: Icons.refresh,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final input1 = tester.getSize(find.byType(GsInput).first);
    final input2 = tester.getSize(find.byType(GsInput).last);
    final btn1 = tester.getSize(find.byType(GsButton).first);
    final btn2 = tester.getSize(find.byType(GsButton).last);
    final iconBtn = tester.getSize(find.byType(GsIconButton));

    // ALL 5 CONTROLS MUST HAVE EXACTLY 36.0 HEIGHT
    expect(input1.height, equals(36.0));
    expect(input2.height, equals(36.0));
    expect(btn1.height, equals(36.0));
    expect(btn2.height, equals(36.0));
    expect(iconBtn.height, equals(36.0));
    expect(iconBtn.width, equals(36.0));

    // ALL 5 CONTROLS MUST SHARE THE EXACT SAME TOP Y POSITION
    final top1 = tester.getTopLeft(find.byType(GsInput).first).dy;
    final top2 = tester.getTopLeft(find.byType(GsInput).last).dy;
    final top3 = tester.getTopLeft(find.byType(GsButton).first).dy;
    final top4 = tester.getTopLeft(find.byType(GsButton).last).dy;
    final top5 = tester.getTopLeft(find.byType(GsIconButton)).dy;

    expect(top1, equals(top2));
    expect(top2, equals(top3));
    expect(top3, equals(top4));
    expect(top4, equals(top5));
  });
}
