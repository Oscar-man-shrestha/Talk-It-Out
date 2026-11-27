import 'package:flutter/material.dart';
import 'package:talk_it_out/core/ui/motion.dart';

/// Double-tap the child to like it, with a heart that pops and fades over
/// it (the gesture people know from photo apps). A double tap only ever
/// likes; un-liking stays on the like button so it cannot happen by
/// accident.
class DoubleTapLike extends StatefulWidget {
  const DoubleTapLike({
    required this.child,
    required this.liked,
    required this.onLike,
    super.key,
  });

  final Widget child;
  final bool liked;
  final VoidCallback onLike;

  @override
  State<DoubleTapLike> createState() => _DoubleTapLikeState();
}

class _DoubleTapLikeState extends State<DoubleTapLike>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    tapFeedback();
    _c.forward(from: 0);
    if (!widget.liked) widget.onLike();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: _onDoubleTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          widget.child,
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                if (_c.value == 0 || _c.isCompleted) {
                  return const SizedBox.shrink();
                }
                final grow = Curves.elasticOut.transform(
                  (_c.value / 0.55).clamp(0.0, 1.0),
                );
                final fade =
                    1 -
                    Curves.easeIn.transform(
                      ((_c.value - 0.55) / 0.45).clamp(0.0, 1.0),
                    );
                return Opacity(
                  opacity: fade,
                  child: Transform.scale(
                    scale: 0.4 + 0.8 * grow,
                    child: const Icon(
                      Icons.favorite,
                      key: ValueKey('double-tap-heart'),
                      size: 84,
                      color: Colors.white,
                      shadows: [
                        Shadow(blurRadius: 18, color: Color(0x55000000)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
