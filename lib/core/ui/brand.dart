import 'package:flutter/material.dart';

/// Talk It Out's palette: black and white, with light cream touches
/// (Run 089, chosen by the user over indigo and an all-cream look).
///
/// Black marks what you can act on or what is active: primary buttons,
/// selected chips and tabs, avatars, badges, and your own chat bubbles.
/// Cream is used sparingly: the page background, quiet fills (inputs,
/// inactive chips) and highlight boxes. Cards stay white. Use these
/// tokens instead of raw hex values.
abstract final class Brand {
  // Accent ---------------------------------------------------------------

  /// Filled buttons, selected states, active indicators.
  static const accent = Color(0xFF0A0A0A);

  /// Pressed / hover shade of [accent].
  static const accentStrong = Color(0xFF262626);

  /// Light cream highlight surfaces: info boxes, prompts, soft chips.
  static const accentSoft = Color(0xFFF7F1E6);

  /// Border for [accentSoft] surfaces.
  static const accentBorder = Color(0xFFEADFCC);

  /// Text and icons placed on [accentSoft].
  static const accentInk = Color(0xFF2A2218);

  /// The accent used on dark backgrounds.
  static const accentOnDark = Color(0xFFFFFFFF);

  // Neutrals -------------------------------------------------------------

  /// Page background: a whisper of cream.
  static const canvas = Color(0xFFFCFAF6);

  /// Cards and sheets.
  static const card = Color(0xFFFFFFFF);

  /// Muted fills: inputs, inactive chips, quiet panels (light cream).
  static const muted = Color(0xFFF6F2EA);

  /// Hairline borders (warm light grey).
  static const border = Color(0xFFE7E3DC);

  /// Strong borders (inputs).
  static const borderStrong = Color(0xFF27272A);

  /// Primary text.
  static const ink = Color(0xFF09090B);

  /// Secondary text.
  static const inkSoft = Color(0xFF71717A);

  /// Tertiary text, placeholders, disabled icons.
  static const inkFaint = Color(0xFFA1A1AA);
}
