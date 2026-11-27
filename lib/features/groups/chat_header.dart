import 'package:flutter/material.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/core/ui/app_icons.dart';
import 'package:talk_it_out/features/premium/chat_prefs.dart';

/// Initials avatar for a group: a rounded ink square with a soft gradient.
class GroupAvatar extends StatelessWidget {
  const GroupAvatar({
    required this.name,
    this.size = 40,
    this.live = false,
    super.key,
  });

  final String name;
  final double size;

  /// A small dot for "something waits for you here".
  final bool live;

  static String initials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    return words.take(2).map((w) => w.characters.first.toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.3),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3F3F46), Brand.ink],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              initials(name),
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.36,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (live)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: size * 0.3,
                height: size * 0.3,
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The chat's top bar: back, group avatar, name, a one-line status, and
/// actions. Tapping the name area opens [onTitleTap] (members).
class ChatHeader extends StatelessWidget implements PreferredSizeWidget {
  const ChatHeader({
    required this.title,
    required this.subtitle,
    required this.actions,
    this.onBack,
    this.onTitleTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final VoidCallback? onTitleTap;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    // Black, like the hero headers (Run 125); messages sit on cream below.
    return Material(
      color: const Color(0xFF0A0A0A),
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      child: IconButtonTheme(
        data: IconButtonThemeData(
          style: IconButton.styleFrom(foregroundColor: Colors.white),
        ),
        child: SafeArea(
          bottom: false,
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.25,
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  if (onBack != null)
                    IconButton(
                      tooltip: 'Back',
                      onPressed: onBack,
                      icon: const Icon(
                        PhosphorIconsRegular.caretLeft,
                        size: 19,
                      ),
                    )
                  else
                    const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      key: const ValueKey('chat-title'),
                      onTap: onTitleTap,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0x40FFFFFF),
                                  width: 1.5,
                                ),
                              ),
                              child: GroupAvatar(name: title, size: 40),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.3,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  ...actions,
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A quiet dotted wallpaper behind messages (cream, like paper).
class ChatWallpaper extends StatelessWidget {
  const ChatWallpaper({
    required this.child,
    this.style = ChatWallpaperStyle.dots,
    super.key,
  });

  final Widget child;

  /// Premium members choose it (chat themes); everyone else gets dots.
  final ChatWallpaperStyle style;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: WallpaperPainter(style), child: child);
  }
}

/// Paints a chat wallpaper (also used for the theme previews).
class WallpaperPainter extends CustomPainter {
  const WallpaperPainter(this.style);

  final ChatWallpaperStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Brand.canvas);
    final ink = Paint()
      ..color = const Color(0xFFE9E3D8)
      ..strokeWidth = 1;
    switch (style) {
      case ChatWallpaperStyle.plain:
        return;
      case ChatWallpaperStyle.dots:
        const gap = 22.0;
        for (var y = 6.0; y < size.height; y += gap) {
          final shift = (y / gap).floor().isEven ? 0.0 : gap / 2;
          for (var x = 6.0 + shift; x < size.width; x += gap) {
            canvas.drawCircle(Offset(x, y), 1.1, ink);
          }
        }
      case ChatWallpaperStyle.grid:
        const gap = 28.0;
        for (var x = 0.0; x < size.width; x += gap) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), ink);
        }
        for (var y = 0.0; y < size.height; y += gap) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), ink);
        }
      case ChatWallpaperStyle.waves:
        ink.style = PaintingStyle.stroke;
        const gap = 26.0;
        for (var y = 10.0; y < size.height; y += gap) {
          final path = Path()..moveTo(0, y);
          for (var x = 0.0; x < size.width; x += 40) {
            path.quadraticBezierTo(x + 10, y - 5, x + 20, y);
            path.quadraticBezierTo(x + 30, y + 5, x + 40, y);
          }
          canvas.drawPath(path, ink);
        }
    }
  }

  @override
  bool shouldRepaint(covariant WallpaperPainter oldDelegate) =>
      oldDelegate.style != style;
}
