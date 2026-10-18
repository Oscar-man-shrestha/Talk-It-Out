// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Comment _$CommentFromJson(Map<String, dynamic> json) => _Comment(
  id: json['id'] as String,
  postId: json['post_id'] as String,
  author: Author.fromJson(json['author'] as Map<String, dynamic>),
  content: json['content'] as String,
  nsfwFlag: json['nsfw_flag'] as bool,
  otherFlags: json['other_flags'] == null
      ? const <String, dynamic>{}
      : flagsFromJson(json['other_flags']),
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$CommentToJson(_Comment instance) => <String, dynamic>{
  'id': instance.id,
  'post_id': instance.postId,
  'author': instance.author.toJson(),
  'content': instance.content,
  'nsfw_flag': instance.nsfwFlag,
  'other_flags': instance.otherFlags,
  'created_at': instance.createdAt.toIso8601String(),
};
