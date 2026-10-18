// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'my_message_status.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MyMessageStatus _$MyMessageStatusFromJson(Map<String, dynamic> json) =>
    _MyMessageStatus(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      status: $enumDecode(
        _$MessageStatusEnumMap,
        json['status'],
        unknownValue: MessageStatus.pending,
      ),
      isAnonymous: json['is_anonymous'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$MyMessageStatusToJson(_MyMessageStatus instance) =>
    <String, dynamic>{
      'id': instance.id,
      'group_id': instance.groupId,
      'status': _$MessageStatusEnumMap[instance.status]!,
      'is_anonymous': instance.isAnonymous,
      'created_at': instance.createdAt.toIso8601String(),
    };

const _$MessageStatusEnumMap = {
  MessageStatus.pending: 'pending',
  MessageStatus.accepted: 'accepted',
  MessageStatus.rejected: 'rejected',
};
