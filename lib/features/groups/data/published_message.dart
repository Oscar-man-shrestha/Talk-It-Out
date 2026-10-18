import 'package:freezed_annotation/freezed_annotation.dart';

part 'published_message.freezed.dart';
part 'published_message.g.dart';

@freezed
abstract class DisplaySender with _$DisplaySender {
  const factory DisplaySender({required String id, required String name}) =
      _DisplaySender;

  factory DisplaySender.fromJson(Map<String, dynamic> json) =>
      _$DisplaySenderFromJson(json);
}

/// Group chat message. A null [displaySender] renders as "Anonymous user".
@freezed
abstract class PublishedMessage with _$PublishedMessage {
  const factory PublishedMessage({
    required String id,
    required String groupId,
    required String text,
    DisplaySender? displaySender,
    required DateTime publishedAt,
  }) = _PublishedMessage;

  factory PublishedMessage.fromJson(Map<String, dynamic> json) =>
      _$PublishedMessageFromJson(json);
}
