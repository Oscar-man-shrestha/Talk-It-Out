import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/core/ui/motion.dart';

/// A calm, slowly moving 3D scene behind the sign-in screens: a perspective
/// grid floor drifting toward the viewer, soft light, and a few chat
/// bubbles turning in space. Drawn with a CustomPainter (no WebGL, so it
/// runs on every device). Still when the person asked for less motion.
class AmbientBackground extends StatefulWidget {
  const AmbientBackground({required this.child, super.key});

  final Widget child;

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.ambientAllowed(context)) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c
        ..stop()
        ..value = 0.18;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Brand.canvas),
        RepaintBoundary(child: CustomPaint(painter: _ScenePainter(_c))),
        widget.child,
      ],
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.t) : super(repaint: t);

  final Animation<double> t;

  @override
  void paint(Canvas canvas, Size size) {
    final phase = t.value * 2 * math.pi;
    _glow(canvas, size, phase);
    _floor(canvas, size);
    _bubbles(canvas, size, phase);
  }

  void _glow(Canvas canvas, Size size, double phase) {
    final blobs = [
      (0.18 + 0.05 * math.sin(phase), 0.22, 0.42, Brand.accentSoft),
      (0.82, 0.18 + 0.05 * math.cos(phase), 0.36, const Color(0xFFF1EEE8)),
      (0.55 + 0.06 * math.cos(phase), 0.62, 0.5, Brand.accentSoft),
    ];
    for (final (x, y, r, color) in blobs) {
      final radius = r * size.shortestSide;
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        radius,
        Paint()
          ..color = color.withValues(alpha: 0.9)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.45),
      );
    }
  }

  /// Lines on a floor plane, projected with a simple pinhole camera.
  void _floor(Canvas canvas, Size size) {
    final horizon = size.height * 0.58;
    final cx = size.width / 2;
    const depth = 14;
    final scroll = t.value * depth % 1;
    final paint = Paint()
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Rows: z from far to near; perspective y = horizon + k / z.
    for (var i = 0; i < depth; i++) {
      final z = depth - i - scroll;
      if (z <= 0.4) continue;
      final y = horizon + (size.height * 0.9) / z;
      if (y > size.height) continue;
      final fade = (1 - z / depth).clamp(0.0, 1.0);
      paint.color = Brand.ink.withValues(alpha: 0.07 * fade);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Columns converge to the vanishing point.
    const columns = 18;
    for (var i = -columns; i <= columns; i++) {
      final xNear = cx + i * size.width * 0.12;
      paint.color = Brand.ink.withValues(alpha: 0.05);
      canvas.drawLine(
        Offset(cx + i * 6, horizon),
        Offset(xNear, size.height),
        paint,
      );
    }
    // Soft fade of the floor into the horizon.
    canvas.drawRect(
      Rect.fromLTWH(0, horizon - 1, size.width, size.height * 0.16),
      Paint()
        ..shader =
            const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Brand.canvas, Color(0x00FCFAF6)],
            ).createShader(
              Rect.fromLTWH(0, horizon - 1, size.width, size.height * 0.16),
            ),
    );
  }

  /// Rounded chat bubbles rotating about their own vertical axis.
  void _bubbles(Canvas canvas, Size size, double phase) {
    final specs = [
      (0.14, 0.34, 46.0, 0.0),
      (0.86, 0.44, 38.0, 1.7),
      (0.74, 0.14, 30.0, 3.1),
      (0.28, 0.12, 24.0, 4.4),
    ];
    for (final (x, y, w, offset) in specs) {
      final angle = phase + offset;
      final bob = math.sin(angle) * 8;
      final squash = math.cos(angle).abs().clamp(0.18, 1.0);
      canvas.save();
      canvas.translate(x * size.width, y * size.height + bob);
      // Fake 3D: a turning card narrows as it faces sideways, with a
      // little perspective skew toward its far edge.
      final m = Matrix4.identity()
        ..setEntry(3, 2, 0.0012)
        ..rotateY(angle * 0.5)
        ..rotateX(0.25);
      canvas.transform(m.storage);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: w * 1.6 * squash,
        height: w,
      );
      final face = RRect.fromRectAndRadius(rect, Radius.circular(w * 0.32));
      canvas.drawRRect(
        face.shift(const Offset(0, 6)),
        Paint()
          ..color = Brand.ink.withValues(alpha: 0.05)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawRRect(
        face,
        Paint()..color = Colors.white.withValues(alpha: 0.92),
      );
      canvas.drawRRect(
        face,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Brand.border,
      );
      // Three typing dots.
      final dot = Paint()..color = Brand.ink.withValues(alpha: 0.35);
      for (var d = -1; d <= 1; d++) {
        canvas.drawCircle(Offset(d * w * 0.22 * squash, 0), w * 0.06, dot);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ScenePainter oldDelegate) => false;
}
