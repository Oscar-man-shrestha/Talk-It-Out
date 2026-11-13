import 'package:talk_it_out/core/models/page_result.dart';
import 'package:talk_it_out/features/notifications/data/app_notification.dart';
import 'package:talk_it_out/features/notifications/data/unread_count.dart';

abstract class NotificationRepository {
  Future<PageResult<AppNotification>> list({int? limit, String? cursor});

  Future<AppNotification> markRead(String notificationId);

  /// Marks every unread notification as read.
  Future<void> markAllRead();

  Future<UnreadCount> unreadCount();
}
