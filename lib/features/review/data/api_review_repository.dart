import 'package:dio/dio.dart';
import 'package:talk_it_out/core/api/api_guard.dart';
import 'package:talk_it_out/core/api/endpoints.dart';
import 'package:talk_it_out/core/models/page_result.dart';
import 'package:talk_it_out/features/review/data/raw_message.dart';
import 'package:talk_it_out/features/review/data/review_repository.dart';
import 'package:talk_it_out/features/review/data/review_result.dart';

class ApiReviewRepository implements ReviewRepository {
  ApiReviewRepository(this._dio);

  final Dio _dio;

  @override
  Future<PageResult<RawMessage>> listQueue(
    String groupId, {
    int? limit,
    String? cursor,
  }) {
    return guardApi(() async {
      final response = await _dio.get(
        Endpoints.reviewQueue(groupId),
        queryParameters: pageQuery(limit: limit, cursor: cursor),
      );
      return decodePage(response.data, RawMessage.fromJson);
    });
  }

  @override
  Future<RawMessage> getMessage(String groupId, String messageId) {
    return guardApi(() async {
      final response = await _dio.get(
        Endpoints.reviewMessage(groupId, messageId),
      );
      return RawMessage.fromJson(asJsonMap(response.data));
    });
  }

  @override
  Future<AcceptResult> accept(String messageId) {
    return guardApi(() async {
      final response = await _dio.post(Endpoints.acceptMessage(messageId));
      return AcceptResult.fromJson(asJsonMap(response.data));
    });
  }

  @override
  Future<RejectResult> reject(String messageId) {
    return guardApi(() async {
      final response = await _dio.post(Endpoints.rejectMessage(messageId));
      return RejectResult.fromJson(asJsonMap(response.data));
    });
  }

  @override
  Future<void> requestRewrite(String messageId) {
    return guardApi(() async {
      await _dio.post(Endpoints.rewriteMessage(messageId));
    });
  }
}
