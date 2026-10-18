import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/mock/mock_ids.dart';
import 'package:talk_it_out/core/mock/run_mock.dart';
import 'package:talk_it_out/core/models/enums.dart';
import 'package:talk_it_out/core/models/page_result.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/features/notifications/data/app_notification.dart';
import 'package:talk_it_out/features/notifications/data/notification_repository.dart';
import 'package:talk_it_out/features/notifications/data/unread_count.dart';

class MockNotificationRepository implements NotificationRepository {
  MockNotificationRepository(this._controls) {
    _items.addAll(_seed());
  }

  final MockControls _controls;
  final List<AppNotification> _items = [];

  @override
  Future<PageResult<AppNotification>> list({int? limit, String? cursor}) {
    return runMock(_controls, () {
      final items = List<AppNotification>.of(_items)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return slicePage(items, limit: limit, cursor: cursor);
    });
  }

  @override
  Future<AppNotification> markRead(String notificationId) {
    return runMock(_controls, () {
      final index = _items.indexWhere((item) => item.id == notificationId);
      if (index < 0) {
        throw const RepositoryException(
          code: 'not_found',
          message: AppStrings.notFound,
        );
      }
      final current = _items[index];
      if (current.readAt != null) return current;
      final updated = current.copyWith(readAt: DateTime.now().toUtc());
      _items[index] = updated;
      return updated;
    });
  }

  @override
  Future<UnreadCount> unreadCount() {
    return runMock(_controls, () {
      final count = _items.where((item) => item.isUnread).length;
      return UnreadCount(count: count);
    });
  }

  static List<AppNotification> _seed() {
    const notes = NotificationGroup(
      id: MockIds.notesGroup,
      agenda: 'Making NLP notes',
    );
    const dashboard = NotificationGroup(
      id: MockIds.dashboardGroup,
      agenda: 'Dashboard improvements',
    );
    return [
      AppNotification(
        id: 'n1',
        type: NotificationType.messageRejected,
        refId: 'm303',
        group: notes,
        createdAt: DateTime.utc(2026, 10, 11, 9),
      ),
      AppNotification(
        id: 'n2',
        type: NotificationType.messagePendingReview,
        refId: 'm201',
        group: dashboard,
        createdAt: DateTime.utc(2026, 10, 12, 17),
      ),
      AppNotification(
        id: 'n3',
        type: NotificationType.messageRejected,
        refId: 'm302',
        group: notes,
        createdAt: DateTime.utc(2026, 10, 10, 12),
        readAt: DateTime.utc(2026, 10, 10, 13),
      ),
      AppNotification(
        id: 'n4',
        type: NotificationType.unknown,
        refId: 'ref-unknown',
        group: notes,
        createdAt: DateTime.utc(2026, 10, 12, 18),
      ),
    ];
  }
}
