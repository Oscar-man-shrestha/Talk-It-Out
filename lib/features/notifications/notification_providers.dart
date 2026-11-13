import 'dart:async';

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

  /// Marks one notification read. The list updates first so the tap feels
  /// instant; a failed call restores the previous list and rethrows.
  Future<void> markRead(String notificationId) async {
    final before = state.value;
    if (before == null) return;
    final target = before.where((item) => item.id == notificationId);
    if (target.isEmpty || !target.first.isUnread) return;
    final now = DateTime.now().toUtc();
    state = AsyncData([
      for (final item in before)
        item.id == notificationId ? item.copyWith(readAt: now) : item,
    ]);
    try {
      await ref.read(notificationRepositoryProvider).markRead(notificationId);
    } catch (_) {
      state = AsyncData(before);
      rethrow;
    } finally {
      ref.invalidate(unreadCountProvider);
    }
  }

  Future<void> markAllRead() async {
    final before = state.value;
    if (before == null || before.every((item) => !item.isUnread)) return;
    final now = DateTime.now().toUtc();
    state = AsyncData([
      for (final item in before)
        item.isUnread ? item.copyWith(readAt: now) : item,
    ]);
    try {
      await ref.read(notificationRepositoryProvider).markAllRead();
    } catch (_) {
      state = AsyncData(before);
      rethrow;
    } finally {
      ref.invalidate(unreadCountProvider);
    }
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, List<AppNotification>>(
      NotificationsNotifier.new,
    );

/// How often the unread count is re-checked while the app is in the
/// foreground (D10, decided 2026-11-13: polling, no push service).
const notificationPollInterval = Duration(seconds: 30);

class UnreadCountNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    // Re-check when the app returns to the foreground and every
    // [notificationPollInterval] while it stays there. No polling while the
    // app is in the background.
    final observer = _ResumeObserver(() {
      if (!ref.mounted) return;
      ref.invalidateSelf();
    });
    WidgetsBinding.instance.addObserver(observer);
    final timer = Timer.periodic(notificationPollInterval, (_) {
      if (!ref.mounted || !observer.inForeground) return;
      ref.invalidateSelf();
    });
    ref.onDispose(() {
      timer.cancel();
      WidgetsBinding.instance.removeObserver(observer);
    });
    final previous = state.value;
    final count = await ref.watch(notificationRepositoryProvider).unreadCount();
    // Something new (or newly read elsewhere): refresh the Alerts list too.
    if (previous != null && previous != count.count && ref.mounted) {
      ref.invalidate(notificationsProvider);
    }
    return count.count;
  }
}

final unreadCountProvider = AsyncNotifierProvider<UnreadCountNotifier, int>(
  UnreadCountNotifier.new,
);

class _ResumeObserver extends WidgetsBindingObserver {
  _ResumeObserver(this.onResume);

  final VoidCallback onResume;
  var inForeground = true;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    inForeground = state == AppLifecycleState.resumed;
    if (inForeground) onResume();
  }
}
