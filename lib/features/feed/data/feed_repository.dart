import 'package:talk_it_out/core/models/group.dart';
import 'package:talk_it_out/core/models/page_result.dart';
import 'package:talk_it_out/features/feed/data/comment.dart';
import 'package:talk_it_out/features/feed/data/post.dart';
import 'package:talk_it_out/features/feed/data/reaction_result.dart';

abstract class FeedRepository {
  Future<PageResult<Post>> listPosts({int? limit, String? cursor});

  Future<Post> createPost({required String content});

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
}
