import 'package:flutter/material.dart';

/// Talk It Out's warm "cream and latte" palette (Run 088).
///
/// Cream surfaces, espresso text, and a soft caramel accent for what you
/// can act on or what is active: primary buttons, selected chips and tabs,
/// avatars, badges, and your own chat bubbles. Use these tokens instead of
/// raw hex values.
abstract final class Brand {
  // Accent ---------------------------------------------------------------

  /// Filled buttons, selected states, active indicators. White text on it
  /// meets WCAG AA (4.8:1).
  static const accent = Color(0xFF8F6B45);

  /// Pressed / hover shade of [accent].
  static const accentStrong = Color(0xFF7A5A38);

  /// Quiet tinted surfaces: info banners, highlighted rows, soft chips.
  static const accentSoft = Color(0xFFF5ECDD);

  /// Border for [accentSoft] surfaces.
  static const accentBorder = Color(0xFFE6D5BB);

  /// Text and icons placed on [accentSoft] (6.6:1).
  static const accentInk = Color(0xFF6B4E2E);

  /// The accent used on dark backgrounds.
  static const accentOnDark = Color(0xFFE3C9A3);

  // Neutrals -------------------------------------------------------------

  /// Page background: soft cream.
  static const canvas = Color(0xFFFBF8F2);

  /// Cards and sheets, a touch lighter than the page.
  static const card = Color(0xFFFFFDF9);

  /// Muted fills: inputs, inactive chips, quiet panels.
  static const muted = Color(0xFFF3ECE1);

  /// Hairline borders.
  static const border = Color(0xFFE8DECF);

  /// Strong borders (inputs).
  static const borderStrong = Color(0xFF4A3F35);

  /// Primary text: warm espresso.
  static const ink = Color(0xFF2B2520);

  /// Secondary text.
  static const inkSoft = Color(0xFF786C60);

  /// Tertiary text, placeholders, disabled icons.
  static const inkFaint = Color(0xFFA79B8E);
}
