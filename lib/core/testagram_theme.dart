import 'package:material_ui/material_ui.dart';

/// Shared T social design tokens for Flutter mobile and web.
/// Testagram's own social identity: calm editorial surfaces, clear hierarchy,
/// and a confident evergreen accent across light and dark appearances.
class TestagramTheme {
  const TestagramTheme._();

  static const blue = Color(0xFF148A68);
  static const blueDark = Color(0xFF45C79A);
  // Compatibility aliases used by existing decorative background widgets.
  static const green = blue;
  static const greenDark = blueDark;
  static const lightBackground = Color(0xFFFFFFFF);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightRaised = Color(0xFFF3F7F5);
  static const lightBorder = Color(0xFFE1EAE5);
  static const darkBackground = Color(0xFF09110F);
  static const darkSurface = Color(0xFF101A17);
  static const darkRaised = Color(0xFF192621);
  static const darkBorder = Color(0xFF293B33);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final surface = isDark ? darkSurface : lightSurface;
    final background = isDark ? darkBackground : lightBackground;
    final raised = isDark ? darkRaised : lightRaised;
    final border = isDark ? darkBorder : lightBorder;
    final primary = isDark ? blueDark : blue;
    final scheme = ColorScheme.fromSeed(
      seedColor: blue,
      brightness: brightness,
      surface: surface,
      primary: primary,
      secondary: primary,
      outline: border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: surface.withValues(alpha: 0.96),
        foregroundColor: isDark ? const Color(0xFFF4F7FA) : const Color(0xFF15202B),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: isDark ? const Color(0xFFF4F7FA) : const Color(0xFF15202B),
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.55,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: raised,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primary, width: 1.6),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        elevation: 0,
        indicatorColor: primary.withValues(alpha: 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 10.5,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w500,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withValues(alpha: 0.12),
        selectedIconTheme: IconThemeData(color: primary),
        unselectedIconTheme: IconThemeData(
          color: isDark ? const Color(0xFF9AA8B7) : const Color(0xFF657786),
        ),
        selectedLabelTextStyle: TextStyle(
          color: primary,
          fontWeight: FontWeight.w800,
        ),
      ),
      dividerColor: border,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: border),
        backgroundColor: raised,
        selectedColor: primary.withValues(alpha: 0.12),
        labelStyle: TextStyle(
          color: isDark ? const Color(0xFFE8EEF5) : const Color(0xFF243447),
        ),
      ),
    );
  }
}
