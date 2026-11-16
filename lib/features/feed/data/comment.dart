import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:talk_it_out/core/models/json_readers.dart';
import 'package:talk_it_out/features/feed/data/author.dart';

part 'comment.freezed.dart';
part 'comment.g.dart';

@freezed
abstract class Comment with _$Comment {
  const factory Comment({
    required String id,
    required String postId,
    required Author author,
    required String content,
    required bool nsfwFlag,
    @JsonKey(fromJson: flagsFromJson)
    @Default(<String, dynamic>{})
    Map<String, dynamic> otherFlags,
    required DateTime createdAt,

    /// How many people reported this comment. Only the question's author
    /// gets a number; everyone else gets null.
    int? reportCount,
    @Default(false) bool reportedByMe,

    /// Upvotes on this answer, and whether you gave one (`API.md` 65).
    @Default(0) int voteCount,
    @Default(false) bool votedByMe,

    /// The asker marked this as the best answer.
    @Default(false) bool isBest,

    /// Set when the author edited the answer.
    DateTime? editedAt,
  }) = _Comment;

  factory Comment.fromJson(Map<String, dynamic> json) =>
      _$CommentFromJson(json);
}
