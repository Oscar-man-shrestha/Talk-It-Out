import 'package:flutter/material.dart';
import 'package:talk_it_out/core/ui/brand.dart';

/// Shared surface tokens (Run 117): the soft, layered shadow that makes
/// white cards float a little above the cream canvas.
abstract final class Surfaces {
  static const radius = 20.0;

  static const shadow = [
    BoxShadow(color: Color(0x120B0B0F), blurRadius: 30, offset: Offset(0, 12)),
    BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 1)),
  ];

  static const raisedShadow = [
    BoxShadow(color: Color(0x14000000), blurRadius: 32, offset: Offset(0, 14)),
    BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2)),
  ];

  static BoxDecoration card({double radius = Surfaces.radius}) => BoxDecoration(
    color: Brand.card,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: Brand.border),
    boxShadow: shadow,
  );
}

/// Gives any child the card shadow without changing its own decoration.
class SoftShadow extends StatelessWidget {
  const SoftShadow({
    required this.child,
    this.radius = Surfaces.radius,
    super.key,
  });

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: Surfaces.shadow,
      ),
      child: child,
    );
  }
}
