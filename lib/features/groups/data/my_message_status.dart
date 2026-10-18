import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:talk_it_out/core/models/enums.dart';

part 'my_message_status.freezed.dart';
part 'my_message_status.g.dart';

/// The sender's own message, status only. No body and no rejection reason.
@freezed
abstract class MyMessageStatus with _$MyMessageStatus {
  const factory MyMessageStatus({
    required String id,
    required String groupId,
    @JsonKey(unknownEnumValue: MessageStatus.pending)
    required MessageStatus status,
    required bool isAnonymous,
    required DateTime createdAt,
  }) = _MyMessageStatus;

  factory MyMessageStatus.fromJson(Map<String, dynamic> json) =>
      _$MyMessageStatusFromJson(json);
}
