import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:talk_it_out/core/models/enums.dart';

part 'review_result.freezed.dart';
part 'review_result.g.dart';

@freezed
abstract class AcceptResult with _$AcceptResult {
  const factory AcceptResult({
    required String id,
    @JsonKey(unknownEnumValue: MessageStatus.pending)
    required MessageStatus status,
    required String publishedMessageId,
  }) = _AcceptResult;

  factory AcceptResult.fromJson(Map<String, dynamic> json) =>
      _$AcceptResultFromJson(json);
}

@freezed
abstract class RejectResult with _$RejectResult {
  const factory RejectResult({
    required String id,
    @JsonKey(unknownEnumValue: MessageStatus.pending)
    required MessageStatus status,
  }) = _RejectResult;

  factory RejectResult.fromJson(Map<String, dynamic> json) =>
      _$RejectResultFromJson(json);
}
