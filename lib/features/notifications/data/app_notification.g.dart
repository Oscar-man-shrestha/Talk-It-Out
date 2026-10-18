// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_notification.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_NotificationGroup _$NotificationGroupFromJson(Map<String, dynamic> json) =>
    _NotificationGroup(
      id: json['id'] as String,
      agenda: json['agenda'] as String,
    );

Map<String, dynamic> _$NotificationGroupToJson(_NotificationGroup instance) =>
    <String, dynamic>{'id': instance.id, 'agenda': instance.agenda};

_AppNotification _$AppNotificationFromJson(Map<String, dynamic> json) =>
    _AppNotification(
      id: json['id'] as String,
      type: $enumDecode(
        _$NotificationTypeEnumMap,
        json['type'],
        unknownValue: NotificationType.unknown,
      ),
      refId: json['ref_id'] as String,
      group: NotificationGroup.fromJson(json['group'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['created_at'] as String),
      readAt: json['read_at'] == null
          ? null
          : DateTime.parse(json['read_at'] as String),
    );

Map<String, dynamic> _$AppNotificationToJson(_AppNotification instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$NotificationTypeEnumMap[instance.type]!,
      'ref_id': instance.refId,
      'group': instance.group.toJson(),
      'created_at': instance.createdAt.toIso8601String(),
      'read_at': instance.readAt?.toIso8601String(),
    };

const _$NotificationTypeEnumMap = {
  NotificationType.messageRejected: 'message_rejected',
  NotificationType.messagePendingReview: 'message_pending_review',
  NotificationType.unknown: 'unknown',
};
