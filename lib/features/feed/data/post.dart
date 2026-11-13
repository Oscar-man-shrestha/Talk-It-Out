import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:talk_it_out/core/models/json_readers.dart';
import 'package:talk_it_out/features/feed/data/author.dart';

part 'post.freezed.dart';
part 'post.g.dart';

@freezed
abstract class Post with _$Post {
  const factory Post({
    required String id,
    required Author author,

    /// Question title (`API.md` 42); null for posts made without one.
    String? title,

    /// One of [PostTopic] ids, or null.
    String? topic,
    required String content,
    required bool nsfwFlag,
    @JsonKey(fromJson: flagsFromJson)
    @Default(<String, dynamic>{})
    Map<String, dynamic> otherFlags,
    required int reactionCount,
    String? myReaction,
    required int commentCount,
    required DateTime createdAt,
  }) = _Post;

  factory Post.fromJson(Map<String, dynamic> json) => _$PostFromJson(json);
}
