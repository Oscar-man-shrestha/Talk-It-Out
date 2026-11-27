import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/core/ui/app_icons.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/core/ui/motion.dart';
import 'package:talk_it_out/features/auth/session_controller.dart';
import 'package:talk_it_out/features/profile/profile_state.dart';
import 'package:talk_it_out/features/premium/premium_promo.dart';

/// The desktop sidebar (Run 119): brand, the four sections with live
/// counts, a primary action, and who is signed in.
class SideNav extends ConsumerWidget {
  const SideNav({
    required this.index,
    required this.onSelect,
    required this.groupUnread,
    required this.alertsUnread,
    super.key,
  });

  /// Wider than this, the app shows the sidebar instead of the tab bar.
  static const breakpoint = 1000.0;

  final int index;
  final ValueChanged<int> onSelect;
  final int groupUnread;
  final int alertsUnread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).value;
    final profile = ref.watch(userProfileProvider);
    final items = [
      (
        PhosphorIconsRegular.chatsCircle,
        PhosphorIconsFill.chatsCircle,
        AppStrings.navGroups,
        groupUnread,
      ),
      (
        PhosphorIconsRegular.compass,
        PhosphorIconsFill.compass,
        AppStrings.navFeed,
        0,
      ),
      (
        PhosphorIconsRegular.bell,
        PhosphorIconsFill.bell,
        'Alerts',
        alertsUnread,
      ),
      (
        PhosphorIconsRegular.userCircle,
        PhosphorIconsFill.userCircle,
        AppStrings.navProfile,
        0,
      ),
    ];
    return Container(
      width: 252,
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        border: Border(right: BorderSide(color: Brand.border)),
      ),
      child: SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Brand
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 22),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF3F3F46), Brand.ink],
                        ),
                      ),
                      child: const Icon(
                        PhosphorIconsFill.chatsTeardrop,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 11),
                    const Expanded(
                      child: Text(
                        AppStrings.appName,
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          color: Brand.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              for (final (i, item) in items.indexed)
                _NavItem(
                  key: ValueKey('side-nav-$i'),
                  icon: index == i ? item.$2 : item.$1,
                  label: item.$3,
                  count: item.$4,
                  selected: index == i,
                  onTap: () => onSelect(i),
                ),
              const SizedBox(height: 18),
              PressScale(
                child: FilledButton.icon(
                  onPressed: () => context.push('/groups/new'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(PhosphorIconsRegular.plus, size: 17),
                  label: const Text('New group'),
                ),
              ),
              const SizedBox(height: 8),
              const SidebarPremiumButton(),
              const Spacer(),
              // Who is signed in
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onSelect(3),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: Brand.ink,
                        foregroundImage: profile.avatarUrl != null
                            ? NetworkImage(profile.avatarUrl!)
                            : null,
                        child: Text(
                          _initials(user?.name ?? ''),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: Brand.ink,
                              ),
                            ),
                            Text(
                              user?.email ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Brand.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        PhosphorIconsRegular.caretUpDown,
                        size: 16,
                        color: Brand.inkFaint,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final letters = words.take(2).map((w) => w[0].toUpperCase()).join();
    return letters.isEmpty ? '?' : letters;
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: selected ? Brand.ink : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: AnimatedContainer(
            duration: Motion.fast,
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? Colors.white : Brand.inkSoft,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? Colors.white : Brand.inkSoft,
                    ),
                  ),
                ),
                if (count > 0)
                  Container(
                    constraints: const BoxConstraints(minWidth: 22),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : Brand.ink,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: selected ? Brand.ink : Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Present above the screens while the sidebar is showing, so a screen can
/// leave out what the sidebar already offers (such as the profile avatar).
class SidebarScope extends InheritedWidget {
  const SidebarScope({required super.child, super.key});

  static bool visible(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SidebarScope>() != null;

  @override
  bool updateShouldNotify(SidebarScope oldWidget) => false;
}
