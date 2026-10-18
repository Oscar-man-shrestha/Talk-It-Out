import 'package:dio/dio.dart';
import 'package:talk_it_out/core/api/api_guard.dart';
import 'package:talk_it_out/core/api/endpoints.dart';
import 'package:talk_it_out/core/models/group.dart';
import 'package:talk_it_out/core/models/group_member.dart';
import 'package:talk_it_out/core/models/page_result.dart';
import 'package:talk_it_out/features/groups/data/group_repository.dart';
import 'package:talk_it_out/features/groups/data/my_message_status.dart';
import 'package:talk_it_out/features/groups/data/published_message.dart';
import 'package:talk_it_out/features/groups/data/sent_message.dart';

class ApiGroupRepository implements GroupRepository {
  ApiGroupRepository(this._dio);

  final Dio _dio;

  @override
  Future<PageResult<Group>> listGroups({int? limit, String? cursor}) {
    return guardApi(() async {
      final response = await _dio.get(
        Endpoints.groups,
        queryParameters: pageQuery(limit: limit, cursor: cursor),
      );
      return decodePage(response.data, Group.fromJson);
    });
  }

  @override
  Future<Group> createGroup({required String agenda}) {
    return guardApi(() async {
      final response = await _dio.post(
        Endpoints.groups,
        data: {'agenda': agenda},
      );
      return Group.fromJson(asJsonMap(response.data));
    });
  }

  @override
  Future<Group> getGroup(String groupId) {
    return guardApi(() async {
      final response = await _dio.get(Endpoints.group(groupId));
      return Group.fromJson(asJsonMap(response.data));
    });
  }

  @override
  Future<PageResult<GroupMember>> listMembers(
    String groupId, {
    int? limit,
    String? cursor,
  }) {
    return guardApi(() async {
      final response = await _dio.get(
        Endpoints.groupMembers(groupId),
        queryParameters: pageQuery(limit: limit, cursor: cursor),
      );
      return decodePage(response.data, GroupMember.fromJson);
    });
  }

  @override
  Future<PageResult<PublishedMessage>> listMessages(
    String groupId, {
    int? limit,
    String? cursor,
  }) {
    return guardApi(() async {
      final response = await _dio.get(
        Endpoints.groupMessages(groupId),
        queryParameters: pageQuery(limit: limit, cursor: cursor),
      );
      return decodePage(response.data, PublishedMessage.fromJson);
    });
  }

  @override
  Future<SentMessage> sendMessage(
    String groupId, {
    required String text,
    required bool isAnonymous,
  }) {
    return guardApi(() async {
      final response = await _dio.post(
        Endpoints.groupMessages(groupId),
        data: {'text': text, 'is_anonymous': isAnonymous},
      );
      return SentMessage.fromJson(asJsonMap(response.data));
    });
  }

  @override
  Future<PageResult<MyMessageStatus>> listMyMessages(
    String groupId, {
    int? limit,
    String? cursor,
  }) {
    return guardApi(() async {
      final response = await _dio.get(
        Endpoints.myMessages(groupId),
        queryParameters: pageQuery(limit: limit, cursor: cursor),
      );
      return decodePage(response.data, MyMessageStatus.fromJson);
    });
  }
}
