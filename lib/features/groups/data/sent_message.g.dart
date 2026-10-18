// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sent_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SentMessage _$SentMessageFromJson(Map<String, dynamic> json) => _SentMessage(
  id: json['id'] as String,
  groupId: json['group_id'] as String,
  status: $enumDecode(
    _$MessageStatusEnumMap,
    json['status'],
    unknownValue: MessageStatus.pending,
  ),
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$SentMessageToJson(_SentMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'group_id': instance.groupId,
      'status': _$MessageStatusEnumMap[instance.status]!,
      'created_at': instance.createdAt.toIso8601String(),
    };

const _$MessageStatusEnumMap = {
  MessageStatus.pending: 'pending',
  MessageStatus.accepted: 'accepted',
  MessageStatus.rejected: 'rejected',
};
