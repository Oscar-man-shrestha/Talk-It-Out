import 'package:flutter/material.dart';
import 'package:talk_it_out/core/ui/app_icons.dart';

/// A small gold crown beside a Premium member's name in the public feed.
/// Never shown in group chats or on anonymous messages (docs/PREMIUM_PLAN.md).
class PremiumBadge extends StatelessWidget {
  const PremiumBadge({this.size = 13, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Premium member',
      child: Container(
        padding: const EdgeInsets.all(2.5),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7D774), Color(0xFFC9932B)],
          ),
        ),
        child: Icon(
          PhosphorIconsFill.crown,
          size: size - 4,
          color: Colors.white,
        ),
      ),
    );
  }
}
