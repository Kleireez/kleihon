import 'package:material_ui/material_ui.dart';

import '../../features/settings/app_settings.dart';

class AppTheme {
  AppTheme._();

  static const String displayFont = 'PlusJakartaSans';
  static const String bodyFont = 'Inter';

  // Palet Dark: Mystic Noir Modern (Gray Fog & Antique Brass)
  static const Color _darkSurface = Color(0xFF111318);
  static const Color _darkNavBar = Color(0xFF14161E);
  static const Color _darkPrimary = Color(0xFFF4CA7E);
  static const Color _darkPrimaryContainer = Color(0xFFD6AF66);
  static const Color _darkHairline = Color(0x24D6AF66); // rgba(214,175,102,0.14)

  // Palet Light: Washi & Sumi Editorial
  static const Color _lightSurface = Color(0xFFFBF9F5);
  static const Color _lightNavBar = Color(0xFFF5F3EF);
  static const Color _lightPrimary = Color(0xFF7D5705);
  static const Color _lightPrimaryContainer = Color(0xFFC89947);
  static const Color _lightHairline = Color(0x1416181D); // rgba(22,24,29,0.08)

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: _darkPrimary,
    onPrimary: Color(0xFF412D00),
    primaryContainer: _darkPrimaryContainer,
    onPrimaryContainer: Color(0xFF5D4200),
    primaryFixed: Color(0xFFFFDEA5),
    primaryFixedDim: Color(0xFFE9C176),
    onPrimaryFixed: Color(0xFF271900),
    onPrimaryFixedVariant: Color(0xFF5D4200),
    secondary: Color(0xFFFFB2B6),
    onSecondary: Color(0xFF66031B),
    secondaryContainer: Color(0xFF892132),
    onSecondaryContainer: Color(0xFFFF9DA3),
    secondaryFixed: Color(0xFFFFDADB),
    secondaryFixedDim: Color(0xFFFFB2B6),
    onSecondaryFixed: Color(0xFF40000D),
    onSecondaryFixedVariant: Color(0xFF861F30),
    tertiary: Color(0xFFCAD0E1),
    onTertiary: Color(0xFF2A303E),
    tertiaryContainer: Color(0xFFAEB4C5),
    onTertiaryContainer: Color(0xFF404654),
    tertiaryFixed: Color(0xFFDCE2F4),
    tertiaryFixedDim: Color(0xFFC0C6D8),
    onTertiaryFixed: Color(0xFF151C28),
    onTertiaryFixedVariant: Color(0xFF404755),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: _darkSurface,
    surfaceDim: _darkSurface,
    surfaceBright: Color(0xFF37393F),
    surfaceContainerLowest: Color(0xFF0C0E13),
    surfaceContainerLow: Color(0xFF1A1B21),
    surfaceContainer: Color(0xFF1E1F25),
    surfaceContainerHigh: Color(0xFF282A2F),
    surfaceContainerHighest: Color(0xFF33353A),
    onSurface: Color(0xFFE2E2E9),
    onSurfaceVariant: Color(0xFFD1C5B4),
    outline: Color(0xFF9A8F80),
    outlineVariant: Color(0xFF4E4639),
    inverseSurface: Color(0xFFE2E2E9),
    onInverseSurface: Color(0xFF2E3036),
    inversePrimary: Color(0xFF785919),
    surfaceTint: Color(0xFFE9C176),
    shadow: Color(0xFF000000),
    scrim: Color(0xC70E1015),
  );

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: _lightPrimary,
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: _lightPrimaryContainer,
    onPrimaryContainer: Color(0xFF4C3300),
    primaryFixed: Color(0xFFFFDEAC),
    primaryFixedDim: Color(0xFFF1BE68),
    onPrimaryFixed: Color(0xFF281900),
    onPrimaryFixedVariant: Color(0xFF5F4100),
    secondary: Color(0xFFAA3341),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFFD717C),
    onSecondaryContainer: Color(0xFF70021C),
    secondaryFixed: Color(0xFFFFDADA),
    secondaryFixedDim: Color(0xFFFFB3B5),
    onSecondaryFixed: Color(0xFF40000C),
    onSecondaryFixedVariant: Color(0xFF891A2C),
    tertiary: Color(0xFF595E6C),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFF9CA1B0),
    onTertiaryContainer: Color(0xFF333844),
    tertiaryFixed: Color(0xFFDEE2F2),
    tertiaryFixedDim: Color(0xFFC2C6D6),
    onTertiaryFixed: Color(0xFF161C27),
    onTertiaryFixedVariant: Color(0xFF424754),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF93000A),
    surface: _lightSurface,
    surfaceDim: Color(0xFFDBDAD6),
    surfaceBright: _lightSurface,
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF5F3EF),
    surfaceContainer: Color(0xFFEFEEEA),
    surfaceContainerHigh: Color(0xFFEAE8E4),
    surfaceContainerHighest: Color(0xFFE4E2DE),
    onSurface: Color(0xFF1B1C1A),
    onSurfaceVariant: Color(0xFF4F4538),
    outline: Color(0xFF817566),
    outlineVariant: Color(0xFFD3C4B2),
    inverseSurface: Color(0xFF30312E),
    onInverseSurface: Color(0xFFF2F0ED),
    inversePrimary: Color(0xFFF1BE68),
    surfaceTint: _lightPrimary,
    shadow: Color(0xFF16181D),
    scrim: Color(0x6616181D),
  );

  static ThemeData get dark => darkFor(AppColorPalette.brass);

  static ThemeData get light => lightFor(AppColorPalette.brass);

  static ThemeData darkFor(AppColorPalette palette) {
    final scheme = _applyPalette(_darkScheme, palette, isDark: true);
    return _buildTheme(
      scheme: scheme,
      navBarColor: _darkNavBar,
      hairline: scheme.primaryContainer.withValues(alpha: 0.16),
      cardColor: scheme.surfaceContainer,
      navUnselected: const Color(0xFF9DA3B4),
    );
  }

  static ThemeData lightFor(AppColorPalette palette) {
    final scheme = _applyPalette(_lightScheme, palette, isDark: false);
    return _buildTheme(
      scheme: scheme,
      navBarColor: _lightNavBar,
      hairline: _lightHairline,
      cardColor: scheme.surfaceContainerLowest,
      navUnselected: const Color(0xFF656A78),
    );
  }

  static ColorScheme _applyPalette(
    ColorScheme base,
    AppColorPalette palette, {
    required bool isDark,
  }) {
    switch (palette) {
      case AppColorPalette.brass:
        return base;
      case AppColorPalette.periwinkle:
        return isDark
            ? base.copyWith(
                primary: const Color(0xFF9AA8FF),
                onPrimary: const Color(0xFF141C4D),
                primaryContainer: const Color(0xFF7C8CFF),
                onPrimaryContainer: const Color(0xFF0A1033),
                secondary: const Color(0xFFF4CA7E),
                onSecondary: const Color(0xFF412D00),
                secondaryContainer: const Color(0xFF5D4200),
                onSecondaryContainer: const Color(0xFFFFDEA5),
                surfaceTint: const Color(0xFF9AA8FF),
              )
            : base.copyWith(
                primary: const Color(0xFF4656C4),
                onPrimary: const Color(0xFFFFFFFF),
                primaryContainer: const Color(0xFF7C8CFF),
                onPrimaryContainer: const Color(0xFF141C4D),
                surfaceTint: const Color(0xFF4656C4),
              );
      case AppColorPalette.crimson:
        return isDark
            ? base.copyWith(
                primary: const Color(0xFFFF9DA3),
                onPrimary: const Color(0xFF5C0A1C),
                primaryContainer: const Color(0xFFCF5663),
                onPrimaryContainer: const Color(0xFFFFDADB),
                secondary: const Color(0xFFF4CA7E),
                onSecondary: const Color(0xFF412D00),
                secondaryContainer: const Color(0xFF5D4200),
                onSecondaryContainer: const Color(0xFFFFDEA5),
                surfaceTint: const Color(0xFFFF9DA3),
              )
            : base.copyWith(
                primary: const Color(0xFFAA3341),
                onPrimary: const Color(0xFFFFFFFF),
                primaryContainer: const Color(0xFFC94A57),
                onPrimaryContainer: const Color(0xFF40000C),
                surfaceTint: const Color(0xFFAA3341),
              );
      case AppColorPalette.jade:
        return isDark
            ? base.copyWith(
                primary: const Color(0xFF7FD8A4),
                onPrimary: const Color(0xFF07381F),
                primaryContainer: const Color(0xFF57B382),
                onPrimaryContainer: const Color(0xFF032111),
                secondary: const Color(0xFFF4CA7E),
                onSecondary: const Color(0xFF412D00),
                secondaryContainer: const Color(0xFF5D4200),
                onSecondaryContainer: const Color(0xFFFFDEA5),
                surfaceTint: const Color(0xFF7FD8A4),
              )
            : base.copyWith(
                primary: const Color(0xFF226D47),
                onPrimary: const Color(0xFFFFFFFF),
                primaryContainer: const Color(0xFF57B382),
                onPrimaryContainer: const Color(0xFF07381F),
                surfaceTint: const Color(0xFF226D47),
              );
    }
  }

  /// Warna garis batas tipis sesuai tema aktif.
  static Color hairlineOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? _darkHairline
        : _lightHairline;
  }

  static ThemeData _buildTheme({
    required ColorScheme scheme,
    required Color navBarColor,
    required Color hairline,
    required Color cardColor,
    required Color navUnselected,
  }) {
    final textTheme = _buildTextTheme(scheme);

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      fontFamily: bodyFont,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 74,
        backgroundColor: navBarColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: scheme.primaryContainer.withValues(alpha: 0.16),
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected ? scheme.primary : navUnselected,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            fontFamily: displayFont,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? scheme.primary : navUnselected,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: hairline),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: hairline,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cardColor,
        selectedColor: scheme.primaryContainer.withValues(alpha: 0.18),
        side: BorderSide(color: hairline),
        shape: const StadiumBorder(),
        labelStyle: textTheme.labelMedium?.copyWith(color: scheme.onSurface),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 46),
          side: BorderSide(color: hairline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: hairline),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface,
        ),
        actionTextColor: scheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: hairline),
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme(ColorScheme scheme) {
    final base = scheme.brightness == Brightness.dark
        ? Typography.material2021().white
        : Typography.material2021().black;

    return base.copyWith(
      displayLarge: TextStyle(
        fontFamily: displayFont,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 40 / 32,
        letterSpacing: -0.5,
        color: scheme.onSurface,
      ),
      displayMedium: TextStyle(
        fontFamily: displayFont,
        fontSize: 26,
        fontWeight: FontWeight.w600,
        height: 34 / 26,
        letterSpacing: -0.25,
        color: scheme.onSurface,
      ),
      headlineLarge: TextStyle(
        fontFamily: displayFont,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 28 / 22,
        color: scheme.onSurface,
      ),
      headlineMedium: TextStyle(
        fontFamily: displayFont,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 26 / 20,
        color: scheme.onSurface,
      ),
      headlineSmall: TextStyle(
        fontFamily: displayFont,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 24 / 18,
        color: scheme.onSurface,
      ),
      titleLarge: TextStyle(
        fontFamily: displayFont,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 24 / 18,
        color: scheme.onSurface,
      ),
      titleMedium: TextStyle(
        fontFamily: displayFont,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 22 / 16,
        letterSpacing: 0.1,
        color: scheme.onSurface,
      ),
      titleSmall: TextStyle(
        fontFamily: displayFont,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 20 / 14,
        letterSpacing: 0.1,
        color: scheme.onSurface,
      ),
      bodyLarge: TextStyle(
        fontFamily: bodyFont,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 22 / 15,
        color: scheme.onSurface,
      ),
      bodyMedium: TextStyle(
        fontFamily: bodyFont,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: scheme.onSurface,
      ),
      bodySmall: TextStyle(
        fontFamily: bodyFont,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 17 / 12,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: TextStyle(
        fontFamily: displayFont,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 18 / 14,
        letterSpacing: 0.2,
        color: scheme.onSurface,
      ),
      labelMedium: TextStyle(
        fontFamily: displayFont,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 16 / 12,
        letterSpacing: 0.3,
        color: scheme.onSurfaceVariant,
      ),
      labelSmall: TextStyle(
        fontFamily: displayFont,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 14 / 11,
        letterSpacing: 0.3,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}
