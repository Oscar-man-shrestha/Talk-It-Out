// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'raw_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RawMessage _$RawMessageFromJson(Map<String, dynamic> json) => _RawMessage(
  id: json['id'] as String,
  groupId: json['group_id'] as String,
  senderId: json['sender_id'] as String,
  senderName: json['sender_name'] as String,
  originalText: json['original_text'] as String,
  rewrittenText: json['rewritten_text'] as String?,
  isAnonymous: json['is_anonymous'] as bool,
  intentPreservationScore: nullableDoubleFromJson(
    json['intent_preservation_score'],
  ),
  relevanceScore: nullableDoubleFromJson(json['relevance_score']),
  relevanceLabel: $enumDecodeNullable(
    _$RelevanceLabelEnumMap,
    json['relevance_label'],
    unknownValue: RelevanceLabel.borderline,
  ),
  pipelineStatus: $enumDecode(
    _$PipelineStatusEnumMap,
    json['pipeline_status'],
    unknownValue: PipelineStatus.processing,
  ),
  status: $enumDecode(
    _$MessageStatusEnumMap,
    json['status'],
    unknownValue: MessageStatus.pending,
  ),
  createdAt: DateTime.parse(json['created_at'] as String),
  decidedAt: json['decided_at'] == null
      ? null
      : DateTime.parse(json['decided_at'] as String),
  attachmentId: json['attachment_id'] as String?,
);

Map<String, dynamic> _$RawMessageToJson(_RawMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'group_id': instance.groupId,
      'sender_id': instance.senderId,
      'sender_name': instance.senderName,
      'original_text': instance.originalText,
      'rewritten_text': instance.rewrittenText,
      'is_anonymous': instance.isAnonymous,
      'intent_preservation_score': instance.intentPreservationScore,
      'relevance_score': instance.relevanceScore,
      'relevance_label': _$RelevanceLabelEnumMap[instance.relevanceLabel],
      'pipeline_status': _$PipelineStatusEnumMap[instance.pipelineStatus]!,
      'status': _$MessageStatusEnumMap[instance.status]!,
      'created_at': instance.createdAt.toIso8601String(),
      'decided_at': instance.decidedAt?.toIso8601String(),
      'attachment_id': instance.attachmentId,
    };

const _$RelevanceLabelEnumMap = {
  RelevanceLabel.relevant: 'relevant',
  RelevanceLabel.borderline: 'borderline',
  RelevanceLabel.offTopic: 'off_topic',
};

const _$PipelineStatusEnumMap = {
  PipelineStatus.queued: 'queued',
  PipelineStatus.processing: 'processing',
  PipelineStatus.done: 'done',
  PipelineStatus.failed: 'failed',
};

const _$MessageStatusEnumMap = {
  MessageStatus.pending: 'pending',
  MessageStatus.accepted: 'accepted',
  MessageStatus.rejected: 'rejected',
};
