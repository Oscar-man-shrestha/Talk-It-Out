import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/core/ui/app_icons.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/features/premium/premium_providers.dart';

/// Premium group templates: one tap fills the group's topic. Without
/// Premium they show a lock and open the Premium screen.
class GroupTemplates extends ConsumerWidget {
  const GroupTemplates({required this.onPick, super.key});

  final ValueChanged<String> onPick;

  static const templates = [
    (AppStrings.templateRetro, AppStrings.templateRetroAgenda),
    (AppStrings.templateClass, AppStrings.templateClassAgenda),
    (AppStrings.templateTownHall, AppStrings.templateTownHallAgenda),
    (AppStrings.templateOneOnOne, AppStrings.templateOneOnOneAgenda),
    (AppStrings.templateExit, AppStrings.templateExitAgenda),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premium = ref.watch(isPremiumProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Flexible(
              child: Text(
                AppStrings.templatesTitle,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Brand.ink,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Brand.accentSoft,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Brand.accentBorder),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    PhosphorIconsFill.crown,
                    size: 11,
                    color: Brand.accentInk,
                  ),
                  SizedBox(width: 4),
                  Text(
                    AppStrings.premium,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Brand.accentInk,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (label, agenda) in templates)
              ActionChip(
                key: ValueKey('template-$label'),
                avatar: Icon(
                  premium
                      ? PhosphorIconsRegular.squaresFour
                      : PhosphorIconsRegular.lockSimple,
                  size: 15,
                  color: premium ? Brand.ink : Brand.inkSoft,
                ),
                label: Text(label),
                onPressed: () =>
                    premium ? onPick(agenda) : context.push('/premium'),
              ),
          ],
        ),
      ],
    );
  }
}
