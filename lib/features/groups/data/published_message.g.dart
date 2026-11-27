// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'published_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DisplaySender _$DisplaySenderFromJson(Map<String, dynamic> json) =>
    _DisplaySender(id: json['id'] as String, name: json['name'] as String);

Map<String, dynamic> _$DisplaySenderToJson(_DisplaySender instance) =>
    <String, dynamic>{'id': instance.id, 'name': instance.name};

_ReplyQuote _$ReplyQuoteFromJson(Map<String, dynamic> json) => _ReplyQuote(
  id: json['id'] as String,
  text: json['text'] as String,
  displaySender: json['display_sender'] == null
      ? null
      : DisplaySender.fromJson(json['display_sender'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ReplyQuoteToJson(_ReplyQuote instance) =>
    <String, dynamic>{
      'id': instance.id,
      'text': instance.text,
      'display_sender': instance.displaySender?.toJson(),
    };

_PollOption _$PollOptionFromJson(Map<String, dynamic> json) => _PollOption(
  text: json['text'] as String,
  votes: (json['votes'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$PollOptionToJson(_PollOption instance) =>
    <String, dynamic>{'text': instance.text, 'votes': instance.votes};

_Poll _$PollFromJson(Map<String, dynamic> json) => _Poll(
  id: json['id'] as String,
  options: (json['options'] as List<dynamic>)
      .map((e) => PollOption.fromJson(e as Map<String, dynamic>))
      .toList(),
  totalVotes: (json['total_votes'] as num?)?.toInt() ?? 0,
  myVote: (json['my_vote'] as num?)?.toInt(),
);

Map<String, dynamic> _$PollToJson(_Poll instance) => <String, dynamic>{
  'id': instance.id,
  'options': instance.options.map((e) => e.toJson()).toList(),
  'total_votes': instance.totalVotes,
  'my_vote': instance.myVote,
};

_PublishedMessage _$PublishedMessageFromJson(Map<String, dynamic> json) =>
    _PublishedMessage(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      text: json['text'] as String,
      displaySender: json['display_sender'] == null
          ? null
          : DisplaySender.fromJson(
              json['display_sender'] as Map<String, dynamic>,
            ),
      attachmentId: json['attachment_id'] as String?,
      replyTo: json['reply_to'] == null
          ? null
          : ReplyQuote.fromJson(json['reply_to'] as Map<String, dynamic>),
      pinned: json['pinned'] as bool? ?? false,
      poll: json['poll'] == null
          ? null
          : Poll.fromJson(json['poll'] as Map<String, dynamic>),
      publishedAt: DateTime.parse(json['published_at'] as String),
    );

Map<String, dynamic> _$PublishedMessageToJson(_PublishedMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'group_id': instance.groupId,
      'text': instance.text,
      'display_sender': instance.displaySender?.toJson(),
      'attachment_id': instance.attachmentId,
      'reply_to': instance.replyTo?.toJson(),
      'pinned': instance.pinned,
      'poll': instance.poll?.toJson(),
      'published_at': instance.publishedAt.toIso8601String(),
    };
