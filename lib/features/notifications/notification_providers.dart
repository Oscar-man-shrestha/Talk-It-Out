import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/features/notifications/data/app_notification.dart';

class NotificationsNotifier extends AsyncNotifier<List<AppNotification>> {
  @override
  Future<List<AppNotification>> build() async {
    final page = await ref.watch(notificationRepositoryProvider).list();
    return page.items;
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, List<AppNotification>>(
      NotificationsNotifier.new,
    );

class UnreadCountNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    final observer = _ResumeObserver(() {
      if (!ref.mounted) return;
      ref.invalidateSelf();
    });
    WidgetsBinding.instance.addObserver(observer);
    ref.onDispose(() => WidgetsBinding.instance.removeObserver(observer));
    final count = await ref.watch(notificationRepositoryProvider).unreadCount();
    return count.count;
  }
}

final unreadCountProvider = AsyncNotifierProvider<UnreadCountNotifier, int>(
  UnreadCountNotifier.new,
);

class _ResumeObserver extends WidgetsBindingObserver {
  _ResumeObserver(this.onResume);

  final VoidCallback onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }
}
