import 'package:flutter/material.dart';

import '../presentation/shared/gs_tokens.dart';

TextStyle _interStyle(double size, [FontWeight weight = FontWeight.w400]) {
  return TextStyle(
    fontSize: size,
    fontWeight: weight,
    letterSpacing: 0,
    height: 1.4,
    fontFeatures: const [FontFeature.tabularFigures()],
    fontVariations: [FontVariation.opticalSize(size.clamp(14.0, 32.0))],
  );
}

ThemeData godsenseTheme() {
  final controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(GsSizes.radius),
  );
  final controlStyle = ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(40, 40)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    visualDensity: VisualDensity.standard,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    shape: WidgetStatePropertyAll(controlShape),
    textStyle: WidgetStatePropertyAll(_interStyle(14, FontWeight.w600)),
    elevation: const WidgetStatePropertyAll(0),
    side: WidgetStateProperty.resolveWith(
      (states) => BorderSide(
        color: states.contains(WidgetState.focused)
            ? GsColors.cyanLight
            : GsColors.borderInteractive,
        width: 1.5,
      ),
    ),
    overlayColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.focused)
          ? const Color(0x4038BDF8)
          : const Color(0x1838BDF8),
    ),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'InterVariable',
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    focusColor: const Color(0x4038BDF8),
    hoverColor: const Color(0x1838BDF8),
    textTheme: TextTheme(
      displayLarge: _interStyle(57),
      displayMedium: _interStyle(45),
      displaySmall: _interStyle(36),
      headlineLarge: _interStyle(32),
      headlineMedium: _interStyle(28, FontWeight.w600),
      headlineSmall: _interStyle(24),
      titleLarge: _interStyle(20, FontWeight.w600),
      titleMedium: _interStyle(16, FontWeight.w600),
      titleSmall: _interStyle(14, FontWeight.w600),
      bodyLarge: _interStyle(16),
      bodyMedium: _interStyle(14),
      bodySmall: _interStyle(13),
      labelLarge: _interStyle(14, FontWeight.w500),
      labelMedium: _interStyle(13, FontWeight.w500),
      labelSmall: _interStyle(12, FontWeight.w500),
    ),
    scaffoldBackgroundColor: GsColors.canvas,
    canvasColor: GsColors.surface,
    colorScheme: const ColorScheme.dark(
      primary: GsColors.cyan,
      onPrimary: Color(0xFF001F2A),
      primaryContainer: Color(0xFF0369A1),
      onPrimaryContainer: GsColors.cyanLight,
      surface: GsColors.surface,
      onSurface: GsColors.textPrimary,
      onSurfaceVariant: GsColors.textSecondary,
      outline: GsColors.borderInteractive,
      outlineVariant: GsColors.border,
      surfaceContainerHigh: GsColors.surfaceElevated,
      error: GsColors.crimson,
      onError: GsColors.canvas,
    ),
    cardTheme: CardThemeData(
      color: GsColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GsSizes.cardRadius),
        side: BorderSide.none,
      ),
    ),
    dividerTheme: const DividerThemeData(color: GsColors.border, thickness: 1),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: controlStyle.copyWith(
        foregroundColor: const WidgetStatePropertyAll(GsColors.textPrimary),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: controlStyle),
    filledButtonTheme: FilledButtonThemeData(style: controlStyle),
    textButtonTheme: TextButtonThemeData(
      style: controlStyle.copyWith(
        side: WidgetStateProperty.resolveWith(
          (s) => BorderSide(
            color: s.contains(WidgetState.focused)
                ? GsColors.cyanLight
                : Colors.transparent,
            width: 1.5,
          ),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: controlStyle.copyWith(
        padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
        iconSize: const WidgetStatePropertyAll(18),
      ),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      minTileHeight: 56,
      iconColor: GsColors.textSecondary,
      titleTextStyle: _interStyle(
        14,
        FontWeight.w500,
      ).copyWith(color: GsColors.textPrimary),
      subtitleTextStyle: _interStyle(13)
          .copyWith(color: GsColors.textSecondary),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 400),
      textStyle: _interStyle(12).copyWith(color: GsColors.textPrimary),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: GsColors.surfaceHover,
        border: Border.all(color: GsColors.borderInteractive),
        borderRadius: BorderRadius.circular(GsSizes.radius),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: GsColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: GsColors.surfaceElevated,
      shape: controlShape,
      textStyle: _interStyle(14).copyWith(color: GsColors.textPrimary),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(8),
      radius: const Radius.circular(8),
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.hovered)
            ? GsColors.textMuted
            : GsColors.borderInteractive,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: GsColors.surfaceHover,
      contentTextStyle: _interStyle(14).copyWith(color: GsColors.textPrimary),
      shape: controlShape,
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      constraints: const BoxConstraints(minHeight: 40),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      prefixIconColor: GsColors.textSecondary,
      suffixIconColor: GsColors.textSecondary,
      filled: true,
      fillColor: GsColors.surfaceElevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: GsColors.borderInteractive),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: GsColors.borderInteractive),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: GsColors.cyan, width: 2),
      ),
      labelStyle: const TextStyle(color: GsColors.textSecondary, fontSize: 14),
      hintStyle: const TextStyle(color: GsColors.textSecondary, fontSize: 14),
    ),
  );
}
