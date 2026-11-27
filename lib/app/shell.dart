import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/features/groups/group_providers.dart';
import 'package:talk_it_out/features/notifications/notification_providers.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/core/ui/motion.dart';
import 'package:talk_it_out/core/ui/app_icons.dart';
import 'package:talk_it_out/app/side_nav.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    final groupUnread = ref.watch(groupsUnreadTotalProvider);
    // Laptops and tablets in landscape: a sidebar instead of the tab bar,
    // so content uses the width (like Slack, Linear, WhatsApp Desktop).
    if (MediaQuery.sizeOf(context).width >= SideNav.breakpoint) {
      return Scaffold(
        body: Row(
          children: [
            SideNav(
              index: navigationShell.currentIndex,
              groupUnread: groupUnread,
              alertsUnread: unread,
              onSelect: (index) {
                tapFeedback();
                navigationShell.goBranch(
                  index,
                  initialLocation: index == navigationShell.currentIndex,
                );
              },
            ),
            // Screens size themselves from the space beside the sidebar.
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(size: Size(box.maxWidth, box.maxHeight)),
                  child: SidebarScope(child: navigationShell),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Brand.border)),
          boxShadow: [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 20,
              offset: Offset(0, -6),
            ),
          ],
        ),
        // The selected tab sits in a black pill with a white icon.
        child: NavigationBarTheme(
          data: NavigationBarTheme.of(context).copyWith(
            iconTheme: WidgetStateProperty.resolveWith(
              (states) => IconThemeData(
                size: 23,
                color: states.contains(WidgetState.selected)
                    ? Colors.white
                    : Brand.inkSoft,
              ),
            ),
            labelTextStyle: WidgetStateProperty.resolveWith(
              (states) => TextStyle(
                fontSize: 11.5,
                letterSpacing: -0.1,
                fontWeight: states.contains(WidgetState.selected)
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: states.contains(WidgetState.selected)
                    ? Brand.ink
                    : Brand.inkSoft,
              ),
            ),
          ),
          child: NavigationBar(
            height: 62,
            indicatorColor: Brand.ink,
            indicatorShape: const StadiumBorder(),
            animationDuration: Motion.medium,
            backgroundColor: Colors.white,
            elevation: 0,
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) {
              tapFeedback();
              navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              );
            },
            destinations: [
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: groupUnread > 0,
                  backgroundColor: Brand.accent,
                  label: Text(unreadBadgeLabel(groupUnread)),
                  child: const Icon(PhosphorIconsRegular.usersThree),
                ),
                selectedIcon: Badge(
                  isLabelVisible: groupUnread > 0,
                  backgroundColor: Colors.white,
                  textColor: Brand.ink,
                  label: Text(unreadBadgeLabel(groupUnread)),
                  child: const Icon(PhosphorIconsFill.usersThree),
                ),
                label: AppStrings.navGroups,
              ),
              const NavigationDestination(
                icon: Icon(PhosphorIconsRegular.compass),
                selectedIcon: Icon(PhosphorIconsFill.compass),
                label: AppStrings.navFeed,
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  child: const Icon(PhosphorIconsRegular.bell),
                ),
                selectedIcon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  child: const Icon(PhosphorIconsFill.bell),
                ),
                label: 'Alerts',
              ),
              const NavigationDestination(
                icon: Icon(PhosphorIconsRegular.userCircle),
                selectedIcon: Icon(PhosphorIconsFill.userCircle),
                label: AppStrings.navProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
