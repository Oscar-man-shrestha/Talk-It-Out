import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/core/ui/motion.dart';

/// A glossy ink emblem that floats and tilts slowly in 3D, with a soft glow
/// beneath it (welcome pages and empty states).
class FloatingEmblem extends StatefulWidget {
  const FloatingEmblem({required this.icon, this.size = 112, super.key});

  final IconData icon;
  final double size;

  @override
  State<FloatingEmblem> createState() => _FloatingEmblemState();
}

class _FloatingEmblemState extends State<FloatingEmblem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.ambientAllowed(context)) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return SizedBox(
      width: size * 1.5,
      height: size * 1.5,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final a = _c.value * 2 * math.pi;
          final lift = math.sin(a) * 6;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Glow on the "floor", smaller while the emblem rises.
              Positioned(
                bottom: size * 0.08,
                child: Container(
                  width: size * (0.8 - lift / 60),
                  height: size * 0.16,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(size),
                    boxShadow: [
                      BoxShadow(
                        color: Brand.ink.withValues(alpha: 0.18),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(0, -lift),
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0015)
                    ..rotateX(math.sin(a) * 0.12)
                    ..rotateY(math.cos(a) * 0.16),
                  child: child,
                ),
              ),
            ],
          );
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              center: Alignment(-0.35, -0.45),
              radius: 1.05,
              colors: [Color(0xFF3F3F46), Brand.ink],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 30,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: Icon(widget.icon, size: size * 0.44, color: Colors.white),
        ),
      ),
    );
  }
}
