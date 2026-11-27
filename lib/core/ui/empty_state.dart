import 'package:flutter/material.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/core/ui/app_icons.dart';

/// One action on an empty screen. The first is drawn as the main button.
class EmptyAction {
  const EmptyAction(this.label, this.onPressed, {this.icon, this.key});

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final Key? key;
}

/// A friendly empty screen: what this place is for and what to do next,
/// instead of a single grey line.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.body,
    this.points = const [],
    this.actions = const [],
    this.inList = false,
    super.key,
  });

  /// True when placed inside a list that already scrolls.
  final bool inList;

  final IconData icon;
  final String title;
  final String body;

  /// Short "how it works" lines with their icons.
  final List<(IconData, String)> points;
  final List<EmptyAction> actions;

  @override
  Widget build(BuildContext context) {
    final content = _content();
    if (inList) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: content,
      );
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
        child: content,
      ),
    );
  }

  Widget _content() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: Brand.accentSoft,
                shape: BoxShape.circle,
                border: Border.all(color: Brand.accentBorder),
              ),
              child: Icon(icon, size: 30, color: Brand.ink),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Brand.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: Brand.inkSoft,
              ),
            ),
            if (points.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Brand.border),
                ),
                child: Column(
                  children: [
                    for (final (pointIcon, text) in points)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(pointIcon, size: 18, color: Brand.ink),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                text,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: Brand.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (actions.isNotEmpty) const SizedBox(height: 18),
            for (final (i, a) in actions.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: i == 0
                      ? FilledButton.icon(
                          key: a.key,
                          onPressed: a.onPressed,
                          style: FilledButton.styleFrom(
                            backgroundColor: Brand.ink,
                            minimumSize: const Size.fromHeight(46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: Icon(
                            a.icon ?? PhosphorIconsRegular.arrowRight,
                            size: 18,
                          ),
                          label: Text(a.label),
                        )
                      : OutlinedButton.icon(
                          key: a.key,
                          onPressed: a.onPressed,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Brand.ink,
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: Icon(
                            a.icon ?? PhosphorIconsRegular.arrowRight,
                            size: 18,
                          ),
                          label: Text(a.label),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
