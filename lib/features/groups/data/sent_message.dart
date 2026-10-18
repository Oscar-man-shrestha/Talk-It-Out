import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:talk_it_out/core/models/enums.dart';

part 'sent_message.freezed.dart';
part 'sent_message.g.dart';

/// Response after sending. The body is not echoed.
@freezed
abstract class SentMessage with _$SentMessage {
  const factory SentMessage({
    required String id,
    required String groupId,
    @JsonKey(unknownEnumValue: MessageStatus.pending)
    required MessageStatus status,
    required DateTime createdAt,
  }) = _SentMessage;

  factory SentMessage.fromJson(Map<String, dynamic> json) =>
      _$SentMessageFromJson(json);
}
