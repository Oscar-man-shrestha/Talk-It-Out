import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:talk_it_out/core/models/enums.dart';

part 'app_notification.freezed.dart';
part 'app_notification.g.dart';

@freezed
abstract class NotificationGroup with _$NotificationGroup {
  const factory NotificationGroup({
    required String id,
    required String agenda,
  }) = _NotificationGroup;

  factory NotificationGroup.fromJson(Map<String, dynamic> json) =>
      _$NotificationGroupFromJson(json);
}

/// The question a feed notification is about (`API.md` 66).
@freezed
abstract class NotificationPost with _$NotificationPost {
  const factory NotificationPost({
    required String id,
    @Default('') String title,
  }) = _NotificationPost;

  factory NotificationPost.fromJson(Map<String, dynamic> json) =>
      _$NotificationPostFromJson(json);
}

@freezed
abstract class AppNotification with _$AppNotification {
  const AppNotification._();

  const factory AppNotification({
    required String id,
    @JsonKey(unknownEnumValue: NotificationType.unknown)
    required NotificationType type,
    required String refId,

    /// Set for group notifications; null for feed ones.
    NotificationGroup? group,

    /// Set for feed notifications (answers, best answer).
    NotificationPost? post,
    required DateTime createdAt,
    DateTime? readAt,
  }) = _AppNotification;

  bool get isUnread => readAt == null;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      _$AppNotificationFromJson(json);
}
