import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/core/ui/app_icons.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/core/ui/motion.dart';
import 'package:talk_it_out/features/premium/premium_providers.dart';
import 'package:talk_it_out/features/premium/premium_screen.dart';

/// On the profile: an invitation to Premium, or the current plan.
class PremiumProfileCard extends ConsumerWidget {
  const PremiumProfileCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ent = ref.watch(entitlementsProvider).value;
    final premium = ent?.premium ?? false;
    final end = ent?.expiresAt;
    final subtitle = !premium
        ? AppStrings.premiumTagline
        : end == null
        ? AppStrings.premiumNoEnd
        : ent!.willRenew
        ? AppStrings.premiumRenews(shortDate(end))
        : AppStrings.premiumEnds(shortDate(end));
    return PressScale(
      scale: 0.985,
      child: Material(
        key: const ValueKey('premium-profile-card'),
        color: premium ? Brand.accentSoft : Brand.ink,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/premium'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: premium
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    premium
                        ? PhosphorIconsFill.sealCheck
                        : PhosphorIconsFill.crown,
                    size: 21,
                    color: premium ? Brand.accentInk : Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        premium
                            ? AppStrings.premiumYouHave
                            : '${AppStrings.premium} · ${AppStrings.premiumPrice}/month',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: premium ? Brand.accentInk : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: premium
                              ? Brand.accentInk
                              : Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  PhosphorIconsRegular.caretRight,
                  size: 18,
                  color: premium ? Brand.accentInk : Colors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Premium tools on the profile: chat theme and starred messages (locked
/// with a crown for free users; tapping opens them or the plans).
class PremiumToolsCard extends ConsumerWidget {
  const PremiumToolsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premium = ref.watch(isPremiumProvider);
    Widget row(
      String key,
      IconData icon,
      String label,
      String route, [
      String? hint,
    ]) => ListTile(
      key: ValueKey(key),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Brand.accentSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Brand.accentBorder),
        ),
        child: Icon(icon, size: 18, color: Brand.ink),
      ),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: Brand.ink,
        ),
      ),
      subtitle: hint == null
          ? null
          : Text(
              hint,
              style: const TextStyle(fontSize: 12.5, color: Brand.inkSoft),
            ),
      trailing: Icon(
        premium ? PhosphorIconsRegular.caretRight : PhosphorIconsFill.crown,
        size: 18,
        color: premium ? Brand.inkFaint : const Color(0xFFC9932B),
      ),
      onTap: () => context.push(premium ? route : '/premium'),
    );
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Brand.border),
      ),
      child: Column(
        children: [
          row(
            'tool-chat-theme',
            PhosphorIconsRegular.sparkle,
            AppStrings.chatThemeTitle,
            '/chat-theme',
            'Your bubble colour and wallpaper',
          ),
          const Divider(height: 1, indent: 68),
          row(
            'tool-starred',
            PhosphorIconsRegular.star,
            AppStrings.starredTitle,
            '/starred',
            'Messages you saved to find later',
          ),
        ],
      ),
    );
  }
}
