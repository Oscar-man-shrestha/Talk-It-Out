import 'package:dio/dio.dart';
import 'package:talk_it_out/core/api/api_guard.dart';
import 'package:talk_it_out/core/models/page_result.dart';
import 'package:talk_it_out/features/discovery/data/discovery_models.dart';
import 'package:talk_it_out/features/discovery/data/discovery_repository.dart';

class ApiDiscoveryRepository implements DiscoveryRepository {
  ApiDiscoveryRepository(this._dio);

  final Dio _dio;

  @override
  Future<PeopleSearchResult> searchPeople(String query, {String? groupId}) {
    return guardApi(() async {
      final response = await _dio.get(
        '/users/search',
        queryParameters: {'q': query, 'group_id': ?groupId},
      );
      return PeopleSearchResult.fromJson(asJsonMap(response.data));
    });
  }

  @override
  Future<List<PersonResult>> suggestedPeople({String? groupId}) {
    return guardApi(() async {
      final response = await _dio.get(
        '/users/suggested',
        queryParameters: {'group_id': ?groupId},
      );
      return PeopleSearchResult.fromJson(asJsonMap(response.data)).items;
    });
  }

  @override
  Future<HandleState> getHandle() {
    return guardApi(() async {
      final response = await _dio.get('/users/me/handle');
      return HandleState.fromJson(asJsonMap(response.data));
    });
  }

  @override
  Future<HandleCheck> checkHandle(String handle) {
    return guardApi(() async {
      final response = await _dio.get(
        '/users/handle-available',
        queryParameters: {'handle': handle},
      );
      return HandleCheck.fromJson(asJsonMap(response.data));
    });
  }

  @override
  Future<String> setHandle(String handle) {
    return guardApi(() async {
      final response = await _dio.put(
        '/users/me/handle',
        data: {'handle': handle},
      );
      final saved = asJsonMap(response.data)['handle'];
      return saved is String ? saved : handle;
    });
  }

  @override
  Future<InterestState> getInterests() {
    return guardApi(() async {
      final response = await _dio.get('/users/me/interests');
      return InterestState.fromJson(asJsonMap(response.data));
    });
  }

  @override
  Future<void> setInterests(List<String> interests) {
    return guardApi(() async {
      await _dio.put('/users/me/interests', data: {'interests': interests});
    });
  }

  @override
  Future<PageResult<RankedPost>> forYou({int? limit, String? cursor}) {
    return guardApi(() async {
      final response = await _dio.get(
        '/posts',
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
        '/posts/search',
        queryParameters: {'q': query},
      );
      return FeedSearchResult.fromJson(asJsonMap(response.data));
    });
  }

  @override
  Future<TopicIdeas> classifyDraft({String? title, required String content}) {
    return guardApi(() async {
      final response = await _dio.post(
        '/posts/classify',
        data: {'title': title, 'content': content},
      );
      return TopicIdeas.fromJson(asJsonMap(response.data));
    });
  }

  @override
  Future<void> sendSignal(String postId, String kind, {bool on = true}) {
    return guardApi(() async {
      await _dio.post('/posts/$postId/signals', data: {'kind': kind, 'on': on});
    });
  }
}
