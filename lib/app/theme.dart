import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:talk_it_out/core/ui/brand.dart';

/// Colors for the Stitch "Monochrome Precision" design system, with the
/// black, white and light cream palette from [Brand] for interactive and selected elements.
const _black = Brand.ink;
const _pureBlack = Color(0xFF000000);
const _pureWhite = Color(0xFFFFFFFF);
const _cream = Brand.card;
const _zinc50 = Brand.canvas;
const _zinc100 = Brand.muted;
const _zinc200 = Brand.border;
const _zinc400 = Brand.inkFaint;
const _zinc500 = Brand.inkSoft;
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
    borderRadius: BorderRadius.circular(12),
  );

  final scaffold = isDark ? _zinc950 : _zinc50;
  final surface = isDark ? _zinc900 : _cream;
  final card = isDark ? _zinc900 : _cream;
  final primary = isDark ? Brand.accentOnDark : Brand.accent;
  final onPrimary = isDark ? _pureBlack : _pureWhite;

  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: isDark ? const Color(0xFF27272A) : Brand.accentSoft,
    onPrimaryContainer: isDark ? Brand.accentSoft : Brand.accentInk,
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
    // Inter, bundled (pubspec.yaml); falls back to the platform font.
    fontFamily: 'Inter',
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: scaffold,
    visualDensity: VisualDensity.standard,
    cardColor: card,
    cardTheme: CardThemeData(
      elevation: 0,
      color: card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      margin: EdgeInsets.zero,
    ),
    // Inner screens: a compact black bar with a rounded bottom, matching
    // the black hero on the main tabs (Run 125).
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Color(0xFF0A0A0A),
      surfaceTintColor: Colors.transparent,
      foregroundColor: Colors.white,
      iconTheme: IconThemeData(color: Colors.white),
      actionsIconTheme: IconThemeData(color: Colors.white),
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: Colors.white,
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
          color: selected ? primary : colorScheme.onSurfaceVariant,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 24,
          color: selected ? primary : colorScheme.onSurfaceVariant,
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
    // Every route fades and rises slightly into place (Run 117).
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _FadeRiseTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: _FadeRiseTransitionsBuilder(),
        TargetPlatform.linux: _FadeRiseTransitionsBuilder(),
        TargetPlatform.fuchsia: _FadeRiseTransitionsBuilder(),
      },
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? _zinc800 : _black,
      contentTextStyle: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        color: _pureWhite,
      ),
      actionTextColor: _pureWhite,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: colorScheme.outlineVariant,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: colorScheme.onSurface,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: card,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: _black,
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: const TextStyle(fontSize: 12, color: _pureWhite),
      waitDuration: const Duration(milliseconds: 400),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colorScheme.surfaceContainerLow,
      selectedColor: primary,
      side: BorderSide(color: colorScheme.outlineVariant),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(fontSize: 13, color: colorScheme.onSurface),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: primary,
      linearTrackColor: colorScheme.outlineVariant,
    ),
  );
}

/// Fade in while rising 3% of the screen: calm and quick, like native apps.
class _FadeRiseTransitionsBuilder extends PageTransitionsBuilder {
  const _FadeRiseTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final enter = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final behind = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.92).animate(behind),
      child: FadeTransition(
        opacity: enter,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(enter),
          child: child,
        ),
      ),
    );
  }
}
