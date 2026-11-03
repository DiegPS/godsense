import 'package:flutter/material.dart';
import 'package:flutter_consistent_ui/flutter_consistent_ui.dart';

abstract final class GsColors {
  static const canvas = Color(0xFFF2F3F7);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceElevated = Color(0xFFF6F5FA);
  static const surfaceHover = Color(0xFFEAE8F3);
  static const border = Color(0xFFDDDDE7);
  static const borderInteractive = Color(0xFF858196);
  static const borderActive = accent;
  static const accent = Color(0xFF6651C8);
  static const accentTint = Color(0xFFEFEBFB);
  static const focus = Color(0xFF4B369A);
  static const onAccent = Color(0xFFFFFFFF);
  static const emerald = Color(0xFF0C7159);
  static const emeraldGlow = Color(0xFFE7F3ED);
  static const crimson = Color(0xFFB63850);
  static const crimsonGlow = Color(0xFFFBECEF);
  static const amber = Color(0xFF8D5B08);
  static const amberGlow = Color(0xFFFCF1D9);
  static const textPrimary = Color(0xFF252237);
  static const textSecondary = Color(0xFF5F5A70);
  static const textMuted = Color(0xFF6B667C);
  static const dangerAction = Color(0xFFB42335);

  static const _brandTone = UiTone(
    strong: accent,
    onStrong: onAccent,
    container: accentTint,
    onContainer: focus,
  );
  static const semantic = UiSemanticColors(
    brand: _brandTone,
    info: _brandTone,
    ai: _brandTone,
    document: _brandTone,
    security: UiTone(
      strong: Color(0xFF365C8C),
      onStrong: onAccent,
      container: Color(0xFFEAF0F8),
      onContainer: Color(0xFF365C8C),
    ),
    success: UiTone(
      strong: emerald,
      onStrong: onAccent,
      container: emeraldGlow,
      onContainer: emerald,
    ),
    warning: UiTone(
      strong: amber,
      onStrong: onAccent,
      container: amberGlow,
      onContainer: amber,
    ),
  );
}

/// Independent high-contrast palette for transparent in-game windows.
abstract final class GsHudColors {
  static const surface = Color(0xFF101620);
  static const border = Color(0xFF2B394C);
  static const cyan = Color(0xFF38BDF8);
  static const crimson = Color(0xFFFF808B);
  static const emerald = Color(0xFF34D399);
  static const amber = Color(0xFFFBBF24);
}

abstract final class GsSizes {
  static const geometry = UiThemeData(
    controlHeight: controlHeight,
    compactControlHeight: controlHeight,
    fontSize: 14,
    lineHeight: 20,
    controlRadius: radius,
    panelRadius: cardRadius,
    formSpacing: 16,
  );
  static const double controlHeight = 40;
  // Density changes horizontal padding, not the shared control baseline.
  static const double controlHeightCompact = controlHeight;
  static const double controlHeightLarge = 48;
  static const double radius = 8;
  static const double cardRadius = 16;
  static const double pageGutter = 24;
  static const double sectionGap = 24;
  static const double contentGap = 16;
  static const double maxPageWidth = 1560;
  static const double icon = 18;

  static double control(BuildContext context, [double? requested]) {
    final config = UiThemeData.of(context);
    final base = MediaQuery.sizeOf(context).width < config.compactBreakpoint
        ? config.compactControlHeight
        : config.controlHeight;
    final shared = UiControlMetrics.height(context);
    return requested != null && requested > base
        ? shared + requested - base
        : shared;
  }

  static EdgeInsets pageInsets(BuildContext context) =>
      EdgeInsets.all(MediaQuery.sizeOf(context).width < 720 ? 16 : pageGutter);
}
