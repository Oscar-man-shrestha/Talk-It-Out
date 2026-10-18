import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/features/groups/group_providers.dart';
import 'package:talk_it_out/features/notifications/notification_providers.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    final groupUnread = ref.watch(groupsUnreadTotalProvider);
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE4E4E7))),
        ),
        child: NavigationBar(
          height: 56,
          indicatorColor: Colors.transparent,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) {
            navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            );
          },
          destinations: [
            NavigationDestination(
              icon: Badge(
                isLabelVisible: groupUnread > 0,
                backgroundColor: Colors.black,
                label: Text(unreadBadgeLabel(groupUnread)),
                child: const Icon(Icons.diversity_3_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: groupUnread > 0,
                backgroundColor: Colors.black,
                label: Text(unreadBadgeLabel(groupUnread)),
                child: const Icon(Icons.diversity_3),
              ),
              label: AppStrings.navGroups,
            ),
            const NavigationDestination(
              icon: Icon(Icons.quiz_outlined),
              selectedIcon: Icon(Icons.quiz),
              label: AppStrings.navFeed,
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                child: const Icon(Icons.notifications_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                child: const Icon(Icons.notifications),
              ),
              label: 'Alerts',
            ),
            const NavigationDestination(
              icon: Icon(Icons.account_circle_outlined),
              selectedIcon: Icon(Icons.account_circle),
              label: AppStrings.navProfile,
            ),
          ],
        ),
      ),
    );
  }
}
