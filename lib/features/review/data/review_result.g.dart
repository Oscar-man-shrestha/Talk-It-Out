// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AcceptResult _$AcceptResultFromJson(Map<String, dynamic> json) =>
    _AcceptResult(
      id: json['id'] as String,
      status: $enumDecode(
        _$MessageStatusEnumMap,
        json['status'],
        unknownValue: MessageStatus.pending,
      ),
      publishedMessageId: json['published_message_id'] as String,
    );

Map<String, dynamic> _$AcceptResultToJson(_AcceptResult instance) =>
    <String, dynamic>{
      'id': instance.id,
      'status': _$MessageStatusEnumMap[instance.status]!,
      'published_message_id': instance.publishedMessageId,
    };

const _$MessageStatusEnumMap = {
  MessageStatus.pending: 'pending',
  MessageStatus.accepted: 'accepted',
  MessageStatus.rejected: 'rejected',
};

_RejectResult _$RejectResultFromJson(Map<String, dynamic> json) =>
    _RejectResult(
      id: json['id'] as String,
      status: $enumDecode(
        _$MessageStatusEnumMap,
        json['status'],
        unknownValue: MessageStatus.pending,
      ),
    );

Map<String, dynamic> _$RejectResultToJson(_RejectResult instance) =>
    <String, dynamic>{
      'id': instance.id,
      'status': _$MessageStatusEnumMap[instance.status]!,
    };
