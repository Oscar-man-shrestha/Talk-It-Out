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
  Future<Post> createPost({required String content}) {
    return guardApi(() async {
      final response = await _dio.post(
        Endpoints.posts,
        data: {'content': content},
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
}
