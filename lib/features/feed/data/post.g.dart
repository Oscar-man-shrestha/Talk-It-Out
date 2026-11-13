// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Post _$PostFromJson(Map<String, dynamic> json) => _Post(
  id: json['id'] as String,
  author: Author.fromJson(json['author'] as Map<String, dynamic>),
  title: json['title'] as String?,
  topic: json['topic'] as String?,
  content: json['content'] as String,
  nsfwFlag: json['nsfw_flag'] as bool,
  otherFlags: json['other_flags'] == null
      ? const <String, dynamic>{}
      : flagsFromJson(json['other_flags']),
  reactionCount: (json['reaction_count'] as num).toInt(),
  myReaction: json['my_reaction'] as String?,
  commentCount: (json['comment_count'] as num).toInt(),
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$PostToJson(_Post instance) => <String, dynamic>{
  'id': instance.id,
  'author': instance.author.toJson(),
  'title': instance.title,
  'topic': instance.topic,
  'content': instance.content,
  'nsfw_flag': instance.nsfwFlag,
  'other_flags': instance.otherFlags,
  'reaction_count': instance.reactionCount,
  'my_reaction': instance.myReaction,
  'comment_count': instance.commentCount,
  'created_at': instance.createdAt.toIso8601String(),
};
