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

/// The message a reply points at, as the group already sees it.
@freezed
abstract class ReplyQuote with _$ReplyQuote {
  const factory ReplyQuote({
    required String id,
    required String text,
    DisplaySender? displaySender,
  }) = _ReplyQuote;

  factory ReplyQuote.fromJson(Map<String, dynamic> json) =>
      _$ReplyQuoteFromJson(json);
}

@freezed
abstract class PollOption with _$PollOption {
  const factory PollOption({required String text, @Default(0) int votes}) =
      _PollOption;

  factory PollOption.fromJson(Map<String, dynamic> json) =>
      _$PollOptionFromJson(json);
}

/// A controller's poll. Only totals are ever shown, never who voted.
@freezed
abstract class Poll with _$Poll {
  const factory Poll({
    required String id,
    required List<PollOption> options,
    @Default(0) int totalVotes,
    int? myVote,
  }) = _Poll;

  factory Poll.fromJson(Map<String, dynamic> json) => _$PollFromJson(json);
}

/// Group chat message. A null [displaySender] renders as "Anonymous user".
@freezed
abstract class PublishedMessage with _$PublishedMessage {
  const factory PublishedMessage({
    required String id,
    required String groupId,
    required String text,
    DisplaySender? displaySender,

    /// An image sent with the message (API.md 49), served to group members.
    String? attachmentId,

    /// The message this one replies to (API.md 50).
    ReplyQuote? replyTo,

    /// Pinned to the top of the chat by the controller.
    @Default(false) bool pinned,

    /// Set when the message is a poll.
    Poll? poll,
    required DateTime publishedAt,
  }) = _PublishedMessage;

  factory PublishedMessage.fromJson(Map<String, dynamic> json) =>
      _$PublishedMessageFromJson(json);
}
