part of 'godsense_app.dart';

TextStyle _interStyle(double size, [FontWeight weight = FontWeight.w400]) {
  return TextStyle(
    fontSize: size,
    fontWeight: weight,
    letterSpacing: 0,
    fontVariations: [FontVariation.opticalSize(size.clamp(14.0, 32.0))],
  );
}

ThemeData godsenseTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'InterVariable',
    textTheme: TextTheme(
      displayLarge: _interStyle(57),
      displayMedium: _interStyle(45),
      displaySmall: _interStyle(36),
      headlineLarge: _interStyle(32),
      headlineMedium: _interStyle(28),
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
      surfaceContainerHigh: GsColors.surfaceElevated,
      error: GsColors.crimson,
      onError: Colors.white,
    ),
    cardTheme: CardThemeData(
      color: GsColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide.none,
      ),
    ),
    dividerTheme: const DividerThemeData(color: GsColors.border, thickness: 1),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(38, 38),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: GsColors.surfaceElevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: GsColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: GsColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: GsColors.cyan),
      ),
      labelStyle: const TextStyle(color: GsColors.textSecondary, fontSize: 14),
      hintStyle: const TextStyle(color: GsColors.textSecondary, fontSize: 14),
    ),
  );
}
