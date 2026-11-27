import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/core/ui/page_padding.dart';

/// The bold header for top-level screens (Groups, Feed, Alerts): a deep
/// black panel with soft light glows, a large white title, an optional
/// one-line subtitle and actions. Rounded at the bottom so the page reads
/// as a sheet beneath it. Static: no endless motion.
class LargeTitleHeader extends StatelessWidget implements PreferredSizeWidget {
  const LargeTitleHeader({
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.background = Colors.white,
    super.key,
  });

  /// Height of the panel below the status bar.
  static const height = 96.0;

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  /// Kept for older callers; the header is always the black hero.
  final Color background;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final side = pageHPad(MediaQuery.sizeOf(context).width);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: HeroInk.ink,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Color(0x29000000),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: CustomPaint(
          painter: const _GlowPainter(),
          child: SafeArea(
            bottom: false,
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.2,
              child: SizedBox(
                height: height,
                child: Padding(
                  // Lines up with the page's centred column on wide screens.
                  padding: EdgeInsets.fromLTRB(
                    side < 22 ? 22 : side,
                    10,
                    side < 14 ? 14 : side,
                    16,
                  ),
                  child: IconTheme.merge(
                    data: const IconThemeData(color: Colors.white),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (subtitle != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: HeroInk.inkSoft,
                                    ),
                                  ),
                                ),
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 32,
                                  height: 1.1,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1.2,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...actions,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Colours for content placed on the black hero.
abstract final class HeroInk {
  static const ink = Color(0xFF0A0A0A);
  static const inkSoft = Color(0xB3FFFFFF);
  static const line = Color(0x33FFFFFF);
  static const fill = Color(0x1AFFFFFF);
}

/// A round avatar button for the hero (white disc, dark icon).
class HeroAvatarButton extends StatelessWidget {
  const HeroAvatarButton({
    required this.onTap,
    this.avatarUrl,
    this.tooltip = 'Profile',
    super.key,
  });

  final VoidCallback onTap;
  final String? avatarUrl;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    const fallback = Icon(Icons.person_outline, size: 19, color: Brand.ink);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(
          side: BorderSide(color: HeroInk.line, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: avatarUrl != null
                ? Image.network(
                    avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => fallback,
                  )
                : fallback,
          ),
        ),
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  const _GlowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    void glow(Offset center, double radius, Color color) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    // Warm cream light from the top right, a cool hint bottom left.
    glow(
      Offset(size.width * 0.92, -size.height * 0.15),
      size.height * 1.5,
      const Color(0x40F7E7C6),
    );
    glow(
      Offset(size.width * 0.05, size.height * 1.2),
      size.height * 1.1,
      const Color(0x1FBFD4FF),
    );
    // Hairline highlight along the bottom edge.
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 1, size.width, 1),
      Paint()..color = const Color(0x14FFFFFF),
    );
  }

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) => false;
}
