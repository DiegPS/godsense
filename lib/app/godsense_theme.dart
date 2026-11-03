import 'package:flutter/material.dart';
import 'package:flutter_consistent_ui/flutter_consistent_ui.dart';

import '../presentation/shared/gs_tokens.dart';

TextStyle _interStyle(double size, [FontWeight weight = FontWeight.w400]) {
  return TextStyle(
    fontFamily: 'InterVariable',
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
            ? GsColors.focus
            : GsColors.borderInteractive,
        width: 1.5,
      ),
    ),
    overlayColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.focused)
          ? GsColors.accent.withValues(alpha: .14)
          : GsColors.accent.withValues(alpha: .07),
    ),
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'InterVariable',
    extensions: const [GsSizes.geometry, GsColors.semantic],
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    focusColor: GsColors.accentTint,
    hoverColor: GsColors.surfaceHover,
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
    colorScheme: const ColorScheme.light(
      primary: GsColors.accent,
      onPrimary: GsColors.onAccent,
      primaryContainer: GsColors.accentTint,
      onPrimaryContainer: GsColors.focus,
      secondary: Color(0xFF365C8C),
      onSecondary: GsColors.onAccent,
      secondaryContainer: Color(0xFFEAF0F8),
      onSecondaryContainer: Color(0xFF365C8C),
      tertiary: GsColors.amber,
      onTertiary: GsColors.onAccent,
      tertiaryContainer: GsColors.amberGlow,
      onTertiaryContainer: GsColors.amber,
      surface: GsColors.surface,
      surfaceContainerLowest: GsColors.surface,
      surfaceContainerLow: GsColors.surface,
      surfaceContainer: GsColors.surface,
      onSurface: GsColors.textPrimary,
      onSurfaceVariant: GsColors.textSecondary,
      outline: GsColors.borderInteractive,
      outlineVariant: GsColors.border,
      surfaceContainerHigh: GsColors.surfaceElevated,
      surfaceContainerHighest: GsColors.surfaceHover,
      inverseSurface: GsColors.surfaceHover,
      onInverseSurface: GsColors.textPrimary,
      inversePrimary: GsColors.accent,
      error: GsColors.crimson,
      onError: GsColors.onAccent,
    ),
    cardTheme: const CardThemeData(color: GsColors.surface, elevation: 0),
    dividerTheme: const DividerThemeData(color: GsColors.border, thickness: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: GsColors.accent,
      linearTrackColor: GsColors.accentTint,
      stopIndicatorColor: GsColors.accent,
    ),
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
                ? GsColors.focus
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      prefixIconColor: GsColors.textSecondary,
      suffixIconColor: GsColors.textSecondary,
      filled: true,
      fillColor: GsColors.surfaceElevated,
      labelStyle: const TextStyle(color: GsColors.textSecondary, fontSize: 14),
      hintStyle: const TextStyle(color: GsColors.textSecondary, fontSize: 14),
    ),
  );
  return UiTheme.apply(
    base,
    geometry: GsSizes.geometry,
    borders: const UiBorderTheme(focusedWidth: 2, focusedErrorWidth: 2),
    surfaces: const UiSurfaceStyle(border: BorderSide(color: GsColors.border)),
  );
}

/// The game overlay must remain readable independently of the desktop theme.
ThemeData godsenseOverlayTheme() => UiTheme.apply(
  ThemeData(
    brightness: Brightness.dark,
    fontFamily: 'InterVariable',
    colorScheme: const ColorScheme.dark(
      primary: GsHudColors.cyan,
      onPrimary: Color(0xFF001F2A),
      surface: GsHudColors.surface,
      onSurface: Color(0xFFF2F6FC),
      error: GsHudColors.crimson,
    ),
  ),
  geometry: GsSizes.geometry,
);
