import 'package:flutter/material.dart';

abstract final class GsColors {
  static const canvas = Color(0xFF080B10);
  static const surface = Color(0xFF101620);
  static const surfaceElevated = Color(0xFF18212E);
  static const surfaceHover = Color(0xFF202D3E);
  static const border = Color(0xFF2B394C);
  static const borderInteractive = Color(0xFF586B82);
  static const borderActive = Color(0xFF38BDF8);
  static const cyan = Color(0xFF38BDF8);
  static const cyanGlow = Color(0x1F38BDF8);
  static const cyanLight = Color(0xFFE0F2FE);
  static const emerald = Color(0xFF34D399);
  static const emeraldGlow = Color(0x1F34D399);
  static const crimson = Color(0xFFFF808B);
  static const crimsonGlow = Color(0x1FFF808B);
  static const amber = Color(0xFFFBBF24);
  static const amberGlow = Color(0x1FFBBF24);
  static const textPrimary = Color(0xFFF2F6FC);
  static const textSecondary = Color(0xFFB2BFD0);
  static const textMuted = Color(0xFF93A4BA);
}

abstract final class GsSizes {
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
    final textHeight = MediaQuery.textScalerOf(context).scale(14) * 1.4 + 20;
    final minimum = requested ?? controlHeight;
    return textHeight > minimum ? textHeight.ceilToDouble() : minimum;
  }

  static EdgeInsets pageInsets(BuildContext context) =>
      EdgeInsets.all(MediaQuery.sizeOf(context).width < 720 ? 16 : pageGutter);
}
