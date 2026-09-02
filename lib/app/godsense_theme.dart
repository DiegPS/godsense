part of 'godsense_app.dart';

ThemeData godsenseTheme() {
  const bgDark = Color(0xFF07090E);
  const surfaceDark = Color(0xFF0C1017);
  const cardDark = Color(0xFF101722);
  const primaryCyan = Color(0xFF38BDF8);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bgDark,
    canvasColor: surfaceDark,
    colorScheme: const ColorScheme.dark(
      primary: primaryCyan,
      onPrimary: Color(0xFF001F2A),
      primaryContainer: Color(0xFF0369A1),
      onPrimaryContainer: Color(0xFFE0F2FE),
      surface: surfaceDark,
      onSurface: Color(0xFFF1F5F9),
      surfaceContainerHigh: cardDark,
    ),
    cardTheme: CardThemeData(
      color: cardDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0x2638BDF8), width: 1),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0x1F38BDF8),
      thickness: 1,
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: surfaceDark,
      indicatorColor: Color(0x330284C7),
      selectedIconTheme: IconThemeData(color: primaryCyan, size: 22),
      unselectedIconTheme: IconThemeData(color: Color(0xFF64748B), size: 20),
      selectedLabelTextStyle: TextStyle(
        color: primaryCyan,
        fontWeight: FontWeight.bold,
        fontSize: 12,
        letterSpacing: 0.5,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: Color(0xFF64748B),
        fontSize: 12,
      ),
    ),
  );
}
