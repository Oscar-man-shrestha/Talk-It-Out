import 'package:talk_it_out/core/models/group.dart';
import 'package:talk_it_out/core/models/page_result.dart';
import 'package:talk_it_out/features/feed/data/comment.dart';
import 'package:talk_it_out/features/feed/data/post.dart';
import 'package:talk_it_out/features/feed/data/reaction_result.dart';

/// An answer's vote count after voting.
class CommentVote {
  const CommentVote({required this.count, required this.votedByMe});

  final int count;
  final bool votedByMe;
}

abstract class FeedRepository {
  /// [topic] (a `PostTopic` id) and [filter] (`unanswered`, `answered`
  /// or `discussed`) are applied by the server (`API.md` 70).
  Future<PageResult<Post>> listPosts({
    int? limit,
    String? cursor,
    String? topic,
    String? filter,
  });

  /// [title] and [topic] are optional (`API.md` 42).
  Future<Post> createPost({
    required String content,
    String? title,
    String? topic,
  });

  Future<Post> getPost(String postId);

  Future<ReactionResult> addReaction(String postId, {required String type});

  Future<ReactionResult> removeReaction(String postId);

  Future<PageResult<Comment>> listComments(
    String postId, {
    int? limit,
    String? cursor,
  });

  Future<Comment> addComment(String postId, {required String content});

  Future<Group> createGroupFromPost(String postId);

  /// Deletes your own question with its likes and comments.
  Future<void> deletePost(String postId);

  /// Removes a comment (its author, or the question's author).
  Future<void> deleteComment(String postId, String commentId);

  /// Reports a comment, or withdraws your report when [report] is false.
  Future<void> reportComment(
    String postId,
    String commentId, {
    bool report = true,
  });

  /// Follow a question to hear about new answers (`API.md` 66).
  Future<bool> setFollowing(String postId, {required bool following});

  /// Upvote an answer, or take the vote back (`API.md` 65).
  Future<CommentVote> voteComment(
    String postId,
    String commentId, {
    required bool up,
  });

  /// The asker marks the best answer; null clears it.
  Future<void> setBestAnswer(String postId, String? commentId);

  /// The author edits their question. Only the fields given change.
  Future<Post> editPost(
    String postId, {
    String? title,
    String? topic,
    String? content,
  });

  /// The author edits their answer.
  Future<Comment> editComment(
    String postId,
    String commentId, {
    required String content,
  });
}
