import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/core/ui/app_icons.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/core/ui/motion.dart';
import 'package:talk_it_out/core/ui/page_padding.dart';
import 'package:talk_it_out/core/ui/surfaces.dart';
import 'package:talk_it_out/features/groups/chat_header.dart';
import 'package:talk_it_out/features/groups/group_providers.dart';
import 'package:talk_it_out/features/premium/chat_prefs.dart';
import 'package:talk_it_out/features/premium/premium_providers.dart';

AppBar _bar(BuildContext context, String title) => AppBar(
  title: Text(
    title,
    style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
  ),
  leading: IconButton(
    tooltip: 'Back',
    icon: const Icon(PhosphorIconsRegular.caretLeft),
    onPressed: () => context.canPop() ? context.pop() : context.go('/profile'),
  ),
);

/// Shown instead of a Premium tool to free users.
class _Locked extends StatelessWidget {
  const _Locked({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: Brand.inkFaint),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Brand.inkSoft),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const ValueKey('locked-get-premium'),
              onPressed: () => context.push('/premium'),
              icon: const Icon(PhosphorIconsFill.crown, size: 17),
              label: const Text(AppStrings.premiumUnlock),
            ),
          ],
        ),
      ),
    );
  }
}

/// Starred messages (Premium): saved on this device, newest first.
class StarredScreen extends ConsumerWidget {
  const StarredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premium = ref.watch(isPremiumProvider);
    final items = ref.watch(starredProvider);
    final groups = {
      for (final g in ref.watch(groupsProvider).value ?? const [])
        g.id: g.agenda,
    };
    final hPad = pageHPad(MediaQuery.sizeOf(context).width, maxContent: 680);
    return Scaffold(
      backgroundColor: Brand.canvas,
      appBar: _bar(context, AppStrings.starredTitle),
      body: !premium
          ? const _Locked(
              icon: PhosphorIconsRegular.star,
              text: AppStrings.starNeedsPremium,
            )
          : items.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  AppStrings.starredEmpty,
                  key: ValueKey('starred-empty'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Brand.inkSoft),
                ),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 32),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final m = items[i];
                return Reveal(
                  index: i,
                  child: Container(
                    key: ValueKey('starred-${m.id}'),
                    padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                    decoration: Surfaces.card(),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            PhosphorIconsFill.star,
                            size: 16,
                            color: Color(0xFFE0A526),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${m.sender} · ${groups[m.groupId] ?? 'Group'}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Brand.inkSoft,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                m.text,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  height: 1.4,
                                  color: Brand.ink,
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () =>
                                    context.push('/groups/${m.groupId}'),
                                child: const Text('Open the chat'),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: AppStrings.unstarMessage,
                          icon: const Icon(PhosphorIconsRegular.x, size: 18),
                          onPressed: () =>
                              ref.read(starredProvider.notifier).remove(m.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// Chat theme (Premium): your bubble colour and the chat wallpaper.
class ChatThemeScreen extends ConsumerWidget {
  const ChatThemeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premium = ref.watch(isPremiumProvider);
    final choice = ref.watch(chatThemeChoiceProvider);
    final notifier = ref.read(chatThemeChoiceProvider.notifier);
    final hPad = pageHPad(MediaQuery.sizeOf(context).width, maxContent: 560);
    if (!premium) {
      return Scaffold(
        backgroundColor: Brand.canvas,
        appBar: _bar(context, AppStrings.chatThemeTitle),
        body: const _Locked(
          icon: PhosphorIconsRegular.sparkle,
          text: AppStrings.premiumFeatureThemesBodyLocked,
        ),
      );
    }
    return Scaffold(
      backgroundColor: Brand.canvas,
      appBar: _bar(context, AppStrings.chatThemeTitle),
      body: ListView(
        padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 32),
        children: [
          // Live preview
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 170,
              child: CustomPaint(
                painter: WallpaperPainter(choice.wallpaper),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _PreviewBubble(
                          text: AppStrings.chatThemePreviewOther,
                          mine: false,
                          colors: choice.accent.colors,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _PreviewBubble(
                          text: AppStrings.chatThemePreviewMine,
                          mine: true,
                          colors: choice.accent.colors,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            AppStrings.chatThemeBubbles,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final a in BubbleAccent.values)
                Semantics(
                  button: true,
                  selected: a == choice.accent,
                  label: a.label,
                  child: GestureDetector(
                    key: ValueKey('accent-${a.name}'),
                    onTap: () => notifier.choose(accent: a),
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: Motion.fast,
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: a.colors),
                            border: Border.all(
                              color: a == choice.accent
                                  ? Brand.ink
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: a == choice.accent
                              ? const Icon(
                                  PhosphorIconsRegular.check,
                                  color: Colors.white,
                                  size: 20,
                                )
                              : null,
                        ),
                        const SizedBox(height: 4),
                        Text(a.label, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            AppStrings.chatThemeWallpaper,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final w in ChatWallpaperStyle.values)
                GestureDetector(
                  key: ValueKey('wallpaper-${w.name}'),
                  onTap: () => notifier.choose(wallpaper: w),
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: Motion.fast,
                        width: 72,
                        height: 92,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: w == choice.wallpaper
                                ? Brand.ink
                                : Brand.border,
                            width: w == choice.wallpaper ? 2.5 : 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CustomPaint(painter: WallpaperPainter(w)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(w.label, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewBubble extends StatelessWidget {
  const _PreviewBubble({
    required this.text,
    required this.mine,
    required this.colors,
  });

  final String text;
  final bool mine;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: mine ? null : Colors.white,
        gradient: mine ? LinearGradient(colors: colors) : null,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(mine ? 18 : 5),
          bottomRight: Radius.circular(mine ? 5 : 18),
        ),
        border: mine ? null : Border.all(color: Brand.border),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 14, color: mine ? Colors.white : Brand.ink),
      ),
    );
  }
}
