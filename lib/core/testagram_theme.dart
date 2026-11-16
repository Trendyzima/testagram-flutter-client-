import 'package:material_ui/material_ui.dart';

/// Testagram's shared visual system.
///
/// Keep product identity in one place so native, web and future surfaces use
/// the same color, type, spacing and component language.
class TestagramTheme {
  const TestagramTheme._();

  // Testagram blue remains the primary brand color. The darker ink and aqua
  // accent create hierarchy without borrowing another network's identity.
  static const blue = Color(0xFF146EF5);
  static const blueDark = Color(0xFF69A7FF);
  static const ink = Color(0xFF101B2B);
  static const mutedInk = Color(0xFF65758B);
  static const aqua = Color(0xFF12B8A6);

  // Compatibility aliases used by existing decorative background widgets.
  static const green = blue;
  static const greenDark = blueDark;

  static const lightBackground = Color(0xFFF6F8FC);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightRaised = Color(0xFFF0F4FA);
  static const lightBorder = Color(0xFFE3E9F2);
  static const darkBackground = Color(0xFF080E18);
  static const darkSurface = Color(0xFF101A29);
  static const darkRaised = Color(0xFF172438);
  static const darkBorder = Color(0xFF29384D);

  static const pagePadding = 20.0;
  static const contentMaxWidth = 1180.0;
  static const cardRadius = 20.0;
  static const controlRadius = 14.0;

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final surface = isDark ? darkSurface : lightSurface;
    final background = isDark ? darkBackground : lightBackground;
    final raised = isDark ? darkRaised : lightRaised;
    final border = isDark ? darkBorder : lightBorder;
    final primary = isDark ? blueDark : blue;
    final foreground = isDark ? const Color(0xFFF3F7FC) : ink;
    final secondaryForeground = isDark
        ? const Color(0xFFA7B5C8)
        : mutedInk;
    final scheme = ColorScheme.fromSeed(
      seedColor: blue,
      brightness: brightness,
      surface: surface,
      primary: primary,
      secondary: isDark ? const Color(0xFF55D7C8) : aqua,
      outline: border,
    );

    final baseText = isDark
        ? Typography.whiteMountainView
        : Typography.blackMountainView;
    final textTheme = baseText.copyWith(
      displayLarge: baseText.displayLarge?.copyWith(
        color: foreground,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.8,
      ),
      displayMedium: baseText.displayMedium?.copyWith(
        color: foreground,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.4,
      ),
      headlineLarge: baseText.headlineLarge?.copyWith(
        color: foreground,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
      ),
      headlineMedium: baseText.headlineMedium?.copyWith(
        color: foreground,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
      ),
      headlineSmall: baseText.headlineSmall?.copyWith(
        color: foreground,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.55,
      ),
      titleLarge: baseText.titleLarge?.copyWith(
        color: foreground,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.35,
      ),
      titleMedium: baseText.titleMedium?.copyWith(
        color: foreground,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: baseText.bodyLarge?.copyWith(
        color: foreground,
        height: 1.45,
      ),
      bodyMedium: baseText.bodyMedium?.copyWith(
        color: foreground,
        height: 1.4,
      ),
      bodySmall: baseText.bodySmall?.copyWith(
        color: secondaryForeground,
        height: 1.4,
      ),
      labelLarge: baseText.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
    );

    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(controlRadius),
      borderSide: BorderSide(color: border),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: background,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 20),
        iconTheme: IconThemeData(color: secondaryForeground),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: raised,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        labelStyle: TextStyle(color: secondaryForeground),
        hintStyle: TextStyle(color: secondaryForeground.withValues(alpha: 0.82)),
        border: outline,
        enabledBorder: outline,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: primary, width: 1.7),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: scheme.error, width: 1.7),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        elevation: 0,
        indicatorColor: primary.withValues(alpha: 0.13),
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
        indicatorColor: primary.withValues(alpha: 0.13),
        selectedIconTheme: IconThemeData(color: primary),
        unselectedIconTheme: IconThemeData(color: secondaryForeground),
        selectedLabelTextStyle: TextStyle(
          color: primary,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelTextStyle: TextStyle(color: secondaryForeground),
      ),
      dividerColor: border,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF223149) : ink,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: border),
        backgroundColor: raised,
        selectedColor: primary.withValues(alpha: 0.13),
        labelStyle: TextStyle(color: foreground),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: raised,
        circularTrackColor: raised,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: secondaryForeground,
        textColor: foreground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
