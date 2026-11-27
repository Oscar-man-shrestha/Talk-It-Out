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
  reportCount: (json['report_count'] as num?)?.toInt(),
  reportedByMe: json['reported_by_me'] as bool? ?? false,
  voteCount: (json['vote_count'] as num?)?.toInt() ?? 0,
  votedByMe: json['voted_by_me'] as bool? ?? false,
  isBest: json['is_best'] as bool? ?? false,
  editedAt: json['edited_at'] == null
      ? null
      : DateTime.parse(json['edited_at'] as String),
);

Map<String, dynamic> _$CommentToJson(_Comment instance) => <String, dynamic>{
  'id': instance.id,
  'post_id': instance.postId,
  'author': instance.author.toJson(),
  'content': instance.content,
  'nsfw_flag': instance.nsfwFlag,
  'other_flags': instance.otherFlags,
  'created_at': instance.createdAt.toIso8601String(),
  'report_count': instance.reportCount,
  'reported_by_me': instance.reportedByMe,
  'vote_count': instance.voteCount,
  'voted_by_me': instance.votedByMe,
  'is_best': instance.isBest,
  'edited_at': instance.editedAt?.toIso8601String(),
};
