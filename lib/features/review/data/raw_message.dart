import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:talk_it_out/core/models/enums.dart';
import 'package:talk_it_out/core/models/json_readers.dart';

part 'raw_message.freezed.dart';
part 'raw_message.g.dart';

/// Controller-only review item. Do not import this from group-facing code.
@freezed
abstract class RawMessage with _$RawMessage {
  const RawMessage._();

  const factory RawMessage({
    required String id,
    required String groupId,
    required String senderId,
    required String senderName,
    required String originalText,
    String? rewrittenText,
    required bool isAnonymous,
    @JsonKey(fromJson: nullableDoubleFromJson) double? intentPreservationScore,
    @JsonKey(fromJson: nullableDoubleFromJson) double? relevanceScore,
    @JsonKey(unknownEnumValue: RelevanceLabel.borderline)
    RelevanceLabel? relevanceLabel,
    @JsonKey(unknownEnumValue: PipelineStatus.processing)
    required PipelineStatus pipelineStatus,
    @JsonKey(unknownEnumValue: MessageStatus.pending)
    required MessageStatus status,
    required DateTime createdAt,
  }) = _RawMessage;

  bool get rewriteUnavailable => pipelineStatus == PipelineStatus.failed;

  factory RawMessage.fromJson(Map<String, dynamic> json) =>
      _$RawMessageFromJson(json);
}
