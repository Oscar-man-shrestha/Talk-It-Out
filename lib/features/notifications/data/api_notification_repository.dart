import 'package:dio/dio.dart';
import 'package:talk_it_out/core/api/api_guard.dart';
import 'package:talk_it_out/core/api/endpoints.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/models/page_result.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/features/notifications/data/app_notification.dart';
import 'package:talk_it_out/features/notifications/data/notification_repository.dart';
import 'package:talk_it_out/features/notifications/data/unread_count.dart';

class ApiNotificationRepository implements NotificationRepository {
  ApiNotificationRepository(this._dio);

  final Dio _dio;

  @override
  Future<PageResult<AppNotification>> list({int? limit, String? cursor}) {
    return guardApi(() async {
      final response = await _dio.get(
        Endpoints.notifications,
        queryParameters: pageQuery(limit: limit, cursor: cursor),
      );
      return decodePage(response.data, AppNotification.fromJson);
    });
  }

  @override
  Future<AppNotification> markRead(String notificationId) {
    return guardApi(() async {
      await _dio.post(Endpoints.notificationRead(notificationId));
      final response = await _dio.get(Endpoints.notifications);
      final page = decodePage(response.data, AppNotification.fromJson);
      for (final item in page.items) {
        if (item.id == notificationId) return item;
      }
      throw const RepositoryException(
        code: 'not_found',
        message: AppStrings.notFound,
      );
    });
  }

  @override
  Future<void> markAllRead() {
    return guardApi(() async {
      await _dio.post(Endpoints.notificationsReadAll);
    });
  }

  @override
  Future<UnreadCount> unreadCount() {
    return guardApi(() async {
      final response = await _dio.get(Endpoints.unreadCount);
      return UnreadCount.fromJson(asJsonMap(response.data));
    });
  }
}
