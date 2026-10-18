// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'published_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DisplaySender _$DisplaySenderFromJson(Map<String, dynamic> json) =>
    _DisplaySender(id: json['id'] as String, name: json['name'] as String);

Map<String, dynamic> _$DisplaySenderToJson(_DisplaySender instance) =>
    <String, dynamic>{'id': instance.id, 'name': instance.name};

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
      publishedAt: DateTime.parse(json['published_at'] as String),
    );

Map<String, dynamic> _$PublishedMessageToJson(_PublishedMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'group_id': instance.groupId,
      'text': instance.text,
      'display_sender': instance.displaySender?.toJson(),
      'published_at': instance.publishedAt.toIso8601String(),
    };
