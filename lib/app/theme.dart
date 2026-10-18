import 'package:flutter/material.dart';

/// Colors for the Stitch "Monochrome Precision" design system.
const _black = Color(0xFF09090B);
const _pureBlack = Color(0xFF000000);
const _pureWhite = Color(0xFFFFFFFF);
const _zinc50 = Color(0xFFFAFAFA);
const _zinc100 = Color(0xFFF4F4F5);
const _zinc200 = Color(0xFFE4E4E7);
const _zinc400 = Color(0xFFA1A1AA);
const _zinc500 = Color(0xFF71717A);
const _zinc800 = Color(0xFF27272A);
const _zinc900 = Color(0xFF18181B);
const _zinc950 = Color(0xFF09090B);
const _errorLight = Color(0xFFBA1A1A);
const _errorDark = Color(0xFFFFB4AB);

final ThemeData lightTheme = _buildTheme(Brightness.light);
final ThemeData darkTheme = _buildTheme(Brightness.dark);

ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  const minTap = Size(48, 48);
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(8),
  );

  final scaffold = isDark ? _zinc950 : _zinc50;
  final surface = isDark ? _zinc900 : _pureWhite;
  final card = isDark ? _zinc900 : _pureWhite;
  final primary = isDark ? _pureWhite : _pureBlack;
  final onPrimary = isDark ? _pureBlack : _pureWhite;

  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: isDark ? _zinc800 : _zinc900,
    onPrimaryContainer: isDark ? _zinc100 : _pureWhite,
    secondary: isDark ? _zinc400 : _zinc500,
    onSecondary: isDark ? _pureBlack : _pureWhite,
    secondaryContainer: isDark ? _zinc800 : _zinc100,
    onSecondaryContainer: isDark ? _zinc200 : _zinc800,
    tertiary: primary,
    onTertiary: onPrimary,
    tertiaryContainer: isDark ? _zinc800 : _zinc100,
    onTertiaryContainer: isDark ? _zinc200 : _zinc800,
    error: isDark ? _errorDark : _errorLight,
    onError: isDark ? const Color(0xFF690005) : _pureWhite,
    surface: surface,
    onSurface: isDark ? _zinc50 : _black,
    onSurfaceVariant: isDark ? _zinc400 : _zinc500,
    outline: isDark ? _zinc500 : _zinc500,
    outlineVariant: isDark ? _zinc800 : _zinc200,
    surfaceContainerLowest: isDark ? _zinc950 : _pureWhite,
    surfaceContainerLow: isDark ? _zinc900 : _zinc50,
    surfaceContainer: card,
    surfaceContainerHigh: isDark ? _zinc800 : const Color(0xFFECECEE),
    surfaceContainerHighest: isDark ? _zinc800 : _zinc200,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: scaffold,
    visualDensity: VisualDensity.standard,
    cardColor: card,
    cardTheme: CardThemeData(
      elevation: 0,
      color: card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      margin: EdgeInsets.zero,
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: surface,
      foregroundColor: colorScheme.onSurface,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: colorScheme.onSurface,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      height: 68,
      backgroundColor: surface,
      indicatorColor: primary.withValues(alpha: isDark ? 0.2 : 0.08),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected
              ? colorScheme.onSurface
              : colorScheme.onSurfaceVariant,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 24,
          color: selected
              ? colorScheme.onSurface
              : colorScheme.onSurfaceVariant,
        );
      }),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: minTap,
        backgroundColor: primary,
        foregroundColor: onPrimary,
        shape: buttonShape,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: minTap,
        shape: buttonShape,
        side: BorderSide(color: colorScheme.outline),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: minTap,
        foregroundColor: primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: minTap),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: onPrimary,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.error, width: 1.5),
      ),
      hintStyle: TextStyle(fontSize: 14, color: colorScheme.outline),
      labelStyle: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outline.withValues(alpha: 0.4),
      thickness: 1,
      space: 1,
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      side: BorderSide(color: colorScheme.outline, width: 1.5),
    ),
  );
}
