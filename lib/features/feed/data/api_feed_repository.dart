import 'package:dio/dio.dart';
import 'package:talk_it_out/core/api/api_guard.dart';
import 'package:talk_it_out/core/api/endpoints.dart';
import 'package:talk_it_out/core/models/group.dart';
import 'package:talk_it_out/core/models/page_result.dart';
import 'package:talk_it_out/features/feed/data/comment.dart';
import 'package:talk_it_out/features/feed/data/feed_repository.dart';
import 'package:talk_it_out/features/feed/data/post.dart';
import 'package:talk_it_out/features/feed/data/reaction_result.dart';

class ApiFeedRepository implements FeedRepository {
  ApiFeedRepository(this._dio);

  final Dio _dio;

  @override
  Future<PageResult<Post>> listPosts({int? limit, String? cursor}) {
    return guardApi(() async {
      final response = await _dio.get(
        Endpoints.posts,
        queryParameters: pageQuery(limit: limit, cursor: cursor),
      );
      return decodePage(response.data, Post.fromJson);
    });
  }

  @override
  Future<Post> createPost({
    required String content,
    String? title,
    String? topic,
  }) {
    return guardApi(() async {
      final response = await _dio.post(
        Endpoints.posts,
        data: {
          'content': content,
          if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
          'topic': ?topic,
        },
      );
      return Post.fromJson(asJsonMap(response.data));
    });
  }

  @override
  Future<Post> getPost(String postId) {
    return guardApi(() async {
      final response = await _dio.get(Endpoints.post(postId));
      return Post.fromJson(asJsonMap(response.data));
    });
  }

  @override
  Future<ReactionResult> addReaction(String postId, {required String type}) {
    return guardApi(() async {
      final response = await _dio.post(
        Endpoints.postReactions(postId),
        data: {'type': type},
      );
      return ReactionResult.fromJson(asJsonMap(response.data));
    });
  }

  @override
  Future<ReactionResult> removeReaction(String postId) {
    return guardApi(() async {
      final response = await _dio.delete(Endpoints.postReactions(postId));
      return ReactionResult.fromJson(asJsonMap(response.data));
    });
  }

  @override
  Future<PageResult<Comment>> listComments(
    String postId, {
    int? limit,
    String? cursor,
  }) {
    return guardApi(() async {
      final response = await _dio.get(
        Endpoints.postComments(postId),
        queryParameters: pageQuery(limit: limit, cursor: cursor),
      );
      return decodePage(response.data, Comment.fromJson);
    });
  }

  @override
  Future<Comment> addComment(String postId, {required String content}) {
    return guardApi(() async {
      final response = await _dio.post(
        Endpoints.postComments(postId),
        data: {'content': content},
      );
      return Comment.fromJson(asJsonMap(response.data));
    });
  }

  @override
  Future<Group> createGroupFromPost(String postId) {
    return guardApi(() async {
      final response = await _dio.post(Endpoints.postGroup(postId));
      return Group.fromJson(asJsonMap(response.data));
    });
  }

  @override
  Future<void> deletePost(String postId) {
    return guardApi(() async {
      await _dio.delete(Endpoints.post(postId));
    });
  }

  @override
  Future<void> deleteComment(String postId, String commentId) {
    return guardApi(() async {
      await _dio.delete(Endpoints.comment(postId, commentId));
    });
  }

  @override
  Future<void> reportComment(
    String postId,
    String commentId, {
    bool report = true,
  }) {
    return guardApi(() async {
      final path = Endpoints.commentReport(postId, commentId);
      if (report) {
        await _dio.post(path);
      } else {
        await _dio.delete(path);
      }
    });
  }

  @override
  Future<bool> setFollowing(String postId, {required bool following}) {
    return guardApi(() async {
      final path = Endpoints.postFollow(postId);
      final response = following
          ? await _dio.post(path)
          : await _dio.delete(path);
      return asJsonMap(response.data)['following'] == true;
    });
  }

  @override
  Future<CommentVote> voteComment(
    String postId,
    String commentId, {
    required bool up,
  }) {
    return guardApi(() async {
      final path = Endpoints.commentVote(postId, commentId);
      final response = up ? await _dio.post(path) : await _dio.delete(path);
      final json = asJsonMap(response.data);
      return CommentVote(
        count: (json['vote_count'] as num?)?.toInt() ?? 0,
        votedByMe: json['voted_by_me'] == true,
      );
    });
  }

  @override
  Future<void> setBestAnswer(String postId, String? commentId) {
    return guardApi(() async {
      await _dio.put(
        Endpoints.postBest(postId),
        data: {'comment_id': commentId},
      );
    });
  }

  @override
  Future<Post> editPost(
    String postId, {
    String? title,
    String? topic,
    String? content,
  }) {
    return guardApi(() async {
      final response = await _dio.patch(
        Endpoints.post(postId),
        data: {'title': ?title, 'topic': ?topic, 'content': ?content},
      );
      return Post.fromJson(asJsonMap(response.data));
    });
  }

  @override
  Future<Comment> editComment(
    String postId,
    String commentId, {
    required String content,
  }) {
    return guardApi(() async {
      final response = await _dio.patch(
        Endpoints.comment(postId, commentId),
        data: {'content': content},
      );
      return Comment.fromJson(asJsonMap(response.data));
    });
  }
}
