part of 'godsense_app.dart';

ThemeData godsenseTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
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
      labelStyle: const TextStyle(color: GsColors.textSecondary, fontSize: 12),
      hintStyle: const TextStyle(color: GsColors.textMuted, fontSize: 12),
    ),
  );
}
