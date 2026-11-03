import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/app/godsense_theme.dart';
import 'package:godsense/presentation/shared/gs_tokens.dart';

double _contrast(Color foreground, Color background) {
  final first = foreground.computeLuminance();
  final second = background.computeLuminance();
  final high = first > second ? first : second;
  final low = first > second ? second : first;
  return (high + .05) / (low + .05);
}

void main() {
  test('desktop and in-game overlay have independent readable themes', () {
    final desktop = godsenseTheme();
    final overlay = godsenseOverlayTheme();
    expect(desktop.brightness, Brightness.light);
    expect(overlay.brightness, Brightness.dark);
    expect(overlay.colorScheme.primary, GsHudColors.cyan);
    expect(overlay.colorScheme.surface, GsHudColors.surface);
    expect(overlay.colorScheme.primary, isNot(desktop.colorScheme.primary));
    expect(
      _contrast(overlay.colorScheme.onSurface, overlay.colorScheme.surface),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(GsColors.onAccent, GsColors.accent),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(GsColors.crimson, GsColors.crimsonGlow),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('body text, status tones and close action meet text contrast', () {
    for (final surface in [
      GsColors.canvas,
      GsColors.surface,
      GsColors.surfaceElevated,
    ]) {
      for (final text in [
        GsColors.textPrimary,
        GsColors.textSecondary,
        GsColors.textMuted,
      ]) {
        expect(_contrast(text, surface), greaterThanOrEqualTo(4.5));
      }
    }
    final colors = GsColors.semantic;
    for (final tone in [
      colors.brand,
      colors.info,
      colors.success,
      colors.warning,
      colors.ai,
      colors.security,
      colors.document,
    ]) {
      expect(_contrast(tone.onStrong, tone.strong), greaterThanOrEqualTo(4.5));
      expect(
        _contrast(tone.onContainer, tone.container),
        greaterThanOrEqualTo(4.5),
      );
    }
    expect(
      _contrast(Colors.white, GsColors.dangerAction),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('native surfaces and library surfaces share the GodSense palette', () {
    final theme = godsenseTheme();
    expect(theme.cardTheme.color, GsColors.surface);
    expect(theme.dialogTheme.backgroundColor, GsColors.surface);
    expect(theme.popupMenuTheme.color, GsColors.surfaceElevated);
    expect(theme.colorScheme.surfaceContainerHigh, GsColors.surfaceElevated);
    expect(theme.textTheme.bodyMedium!.fontFamily, 'InterVariable');
  });
}
