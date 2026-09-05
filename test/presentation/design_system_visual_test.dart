import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/presentation/shared/design_system_previews.dart';

void main() {
  testWidgets('shared visual system', (tester) async {
    tester.view.physicalSize = const Size(1000, 650);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final loader = FontLoader('InterVariable');
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final fonts = manifest.listAssets().where(
      (p) => p.startsWith('assets/fonts/inter/') && p.endsWith('.ttf'),
    );
    if (fonts.isNotEmpty) {
      loader.addFont(
        rootBundle.load(fonts.firstWhere((p) => !p.contains('Italic'))),
      );
      await loader.load();
    }
    await tester.pumpWidget(
      RepaintBoundary(key: const Key('visual'), child: designSystemPreview()),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const Key('visual')),
      matchesGoldenFile('goldens/design_system.png'),
    );
  });
}
