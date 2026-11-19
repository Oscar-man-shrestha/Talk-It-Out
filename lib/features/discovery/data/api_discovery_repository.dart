import 'package:dio/dio.dart';
import 'package:talk_it_out/core/api/api_guard.dart';
import 'package:talk_it_out/core/api/endpoints.dart';
import 'package:talk_it_out/core/models/page_result.dart';
import 'package:talk_it_out/features/discovery/data/discovery_models.dart';
import 'package:talk_it_out/features/discovery/data/discovery_repository.dart';
import 'package:talk_it_out/features/feed/data/post.dart';

class ApiDiscoveryRepository implements DiscoveryRepository {
  ApiDiscoveryRepository(this._dio);

  final Dio _dio;

  @override
  Future<PeopleSearchResult> searchPeople(String query, {String? groupId}) {
    return guardApi(() async {
      final response = await _dio.get(
        Endpoints.usersSearch,
        queryParameters: {'q': query, 'group_id': ?groupId},
      );
      return PeopleSearchResult.fromJson(asJsonMap(response.data));
    });
  }

  @override
  Future<List<PersonResult>> suggestedPeople({String? groupId}) {
    return guardApi(() async {
      final response = await _dio.get(
        Endpoints.usersSuggested,
        queryParameters: {'group_id': ?groupId},
      );
      return PeopleSearchResult.fromJson(asJsonMap(response.data)).items;
    });
  }

  @override
  Future<HandleState> getHandle() {
    return guardApi(() async {
      final response = await _dio.get(Endpoints.myHandle);
      return HandleState.fromJson(asJsonMap(response.data));
    });
  }

  @override
  Future<HandleCheck> checkHandle(String handle) {
    return guardApi(() async {
      final response = await _dio.get(
        Endpoints.handleAvailable,
        queryParameters: {'handle': handle},
      );
      return HandleCheck.fromJson(asJsonMap(response.data));
    });
  }

  @override
  Future<String> setHandle(String handle) {
    return guardApi(() async {
      final response = await _dio.put(
        Endpoints.myHandle,
        data: {'handle': handle},
      );
      final saved = asJsonMap(response.data)['handle'];
      return saved is String ? saved : handle;
    });
  }

  @override
  Future<InterestState> getInterests() {
    return guardApi(() async {
      final response = await _dio.get(Endpoints.myInterests);
      return InterestState.fromJson(asJsonMap(response.data));
    });
  }

  @override
  Future<void> setInterests(List<String> interests) {
    return guardApi(() async {
      await _dio.put(Endpoints.myInterests, data: {'interests': interests});
    });
  }

  @override
  Future<PageResult<RankedPost>> forYou({int? limit, String? cursor}) {
    return guardApi(() async {
      final response = await _dio.get(
        Endpoints.posts,
        queryParameters: {
          'mode': 'for_you',
          ...pageQuery(limit: limit, cursor: cursor),
        },
      );
      return decodePage(response.data, RankedPost.fromJson);
    });
  }

  @override
  Future<FeedSearchResult> searchPosts(String query) {
    return guardApi(() async {
      final response = await _dio.get(
        Endpoints.postsSearch,
        queryParameters: {'q': query},
      );
      return FeedSearchResult.fromJson(asJsonMap(response.data));
    });
  }

  @override
  Future<TopicIdeas> classifyDraft({String? title, required String content}) {
    return guardApi(() async {
      final response = await _dio.post(
        Endpoints.postsClassify,
        data: {'title': title, 'content': content},
      );
      return TopicIdeas.fromJson(asJsonMap(response.data));
    });
  }

  @override
  Future<void> sendSignal(String postId, String kind, {bool on = true}) {
    return guardApi(() async {
      await _dio.post(
        Endpoints.postSignals(postId),
        data: {'kind': kind, 'on': on},
      );
    });
  }

  @override
  Future<void> setPersonalized(bool on) {
    return guardApi(() async {
      await _dio.put(Endpoints.myFeedSettings, data: {'personalized': on});
    });
  }

  @override
  Future<List<SimilarQuestion>> similarQuestions({
    String? title,
    required String content,
  }) {
    return guardApi(() async {
      final response = await _dio.post(
        Endpoints.postsSimilar,
        data: {'title': title, 'content': content},
      );
      final items = asJsonMap(response.data)['items'];
      return [
        if (items is List)
          for (final x in items)
            if (x is Map)
              SimilarQuestion.fromJson(Map<String, dynamic>.from(x)),
      ];
    });
  }

  @override
  Future<PersonProfile> getPerson(String userId) {
    return guardApi(() async {
      final response = await _dio.get(Endpoints.userProfile(userId));
      return PersonProfile.fromJson(asJsonMap(response.data));
    });
  }

  @override
  Future<List<Post>> personPosts(String userId) {
    return guardApi(() async {
      final response = await _dio.get(Endpoints.userPosts(userId));
      return decodePage(response.data, Post.fromJson).items;
    });
  }

  @override
  Future<void> block(String userId) {
    return guardApi(() async {
      await _dio.post(Endpoints.userBlock(userId));
    });
  }

  @override
  Future<void> unblock(String userId) {
    return guardApi(() async {
      await _dio.delete(Endpoints.userBlock(userId));
    });
  }

  @override
  Future<List<PersonResult>> blockedPeople() {
    return guardApi(() async {
      final response = await _dio.get(Endpoints.myBlocked);
      return PeopleSearchResult.fromJson(asJsonMap(response.data)).items;
    });
  }

  @override
  Future<void> reportPost(String postId, ReportReason reason) {
    return guardApi(() async {
      await _dio.post(
        Endpoints.postReport(postId),
        data: {'reason': reason.id},
      );
    });
  }

  @override
  Future<void> withdrawReport(String postId) {
    return guardApi(() async {
      await _dio.delete(Endpoints.postReport(postId));
    });
  }

  @override
  Future<LikersPage> likers(String postId) {
    return guardApi(() async {
      final response = await _dio.get(Endpoints.postLikes(postId));
      return LikersPage.fromJson(asJsonMap(response.data));
    });
  }
}
