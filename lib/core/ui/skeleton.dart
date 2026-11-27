import 'package:flutter/material.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/core/ui/motion.dart';
import 'package:talk_it_out/core/ui/page_padding.dart';

/// A soft light sweep across grey placeholder shapes while content loads
/// (the shape of the page appears at once instead of a spinner).
class Shimmer extends StatefulWidget {
  const Shimmer({required this.child, super.key});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Like the spinner it replaced, it animates whenever loading is on
    // screen (only "reduce motion" stops it); loading always ends.
    if (Motion.entrancesAllowed(context)) {
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
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = _c.value * 3 - 1; // sweep from left of the box to right
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment(t - 1, -0.3),
            end: Alignment(t + 1, 0.3),
            colors: const [Brand.muted, Color(0xFFFFFFFF), Brand.muted],
            stops: const [0.35, 0.5, 0.65],
          ).createShader(rect),
          child: child,
        );
      },
    );
  }
}

/// One grey placeholder block.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({this.width, this.height = 12, this.radius = 6, super.key});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Brand.muted,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Placeholder cards shaped like a list of posts, groups or alerts.
class SkeletonList extends StatelessWidget {
  const SkeletonList({this.count = 5, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final hPad = pageHPad(MediaQuery.sizeOf(context).width);
    return Semantics(
      label: AppStrings.loading,
      child: Shimmer(
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 16),
          itemCount: count,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _SkeletonCard(wide: i.isEven),
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Brand.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Brand.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              SkeletonBox(width: 36, height: 36, radius: 18),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 120),
                    SizedBox(height: 6),
                    SkeletonBox(width: 64, height: 9),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const SkeletonBox(height: 14),
          const SizedBox(height: 8),
          FractionallySizedBox(
            widthFactor: wide ? 0.85 : 0.6,
            child: const SkeletonBox(),
          ),
        ],
      ),
    );
  }
}
