import 'package:talk_it_out/core/models/group.dart';
import 'package:talk_it_out/core/models/page_result.dart';
import 'package:talk_it_out/features/feed/data/comment.dart';
import 'package:talk_it_out/features/feed/data/post.dart';
import 'package:talk_it_out/features/feed/data/reaction_result.dart';

abstract class FeedRepository {
  Future<PageResult<Post>> listPosts({int? limit, String? cursor});

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
}
