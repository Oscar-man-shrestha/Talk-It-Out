/// Horizontal page padding shared by the top bar and screens, so their
/// content lines up on every device:
/// phones (< 600) 12, tablets 20, and on wide screens a centred column
/// [maxContent] wide (never less than 20 at the sides).
///
/// Apply it as padding; do not wrap a ListView in a width constraint
/// (AGENTS.md section 0).
double pageHPad(double screenWidth, {double maxContent = 860}) {
  if (screenWidth < 600) return 12;
  final centred = (screenWidth - maxContent) / 2;
  return centred > 20 ? centred : 20;
}
