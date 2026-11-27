import 'package:dio/dio.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/models/page_result.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';

Map<String, dynamic> asJsonMap(Object? data) {
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  throw const RepositoryException(
    code: 'unknown',
    message: AppStrings.errorGeneric,
  );
}

PageResult<T> decodePage<T>(
  Object? data,
  T Function(Map<String, dynamic> json) decode,
) {
  final json = asJsonMap(data);
  final rawItems = json['items'];
  final items = <T>[];
  if (rawItems is List) {
    for (final raw in rawItems) {
      if (raw is Map) items.add(decode(Map<String, dynamic>.from(raw)));
    }
  }
  final cursor = json['next_cursor'];
  return PageResult(items: items, nextCursor: cursor is String ? cursor : null);
}

Map<String, dynamic> pageQuery({int? limit, String? cursor}) {
  return {
    'limit': ?limit,
    if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
  };
}

RepositoryException repositoryExceptionFromDio(DioException error) {
  final data = error.response?.data;
  if (data is Map && data['error'] is Map) {
    final body = Map<String, dynamic>.from(data['error'] as Map);
    final message = body['message'];
    final code = body['code'];
    if (message is String && message.trim().isNotEmpty) {
      return RepositoryException(
        code: code is String && code.isNotEmpty ? code : 'unknown',
        message: message,
      );
    }
  }

  // No response at all: the server is down or the network is off.
  if (error.response == null &&
      error.type != DioExceptionType.cancel &&
      error.type != DioExceptionType.badCertificate) {
    return const RepositoryException(
      code: 'offline',
      message: AppStrings.serverUnreachable,
    );
  }

  final status = error.response?.statusCode;
  if (status == 401) {
    return const RepositoryException(
      code: 'unauthorized',
      message: AppStrings.sessionExpired,
    );
  }
  if (status == 403) {
    return const RepositoryException(
      code: 'forbidden',
      message: AppStrings.notAllowed,
    );
  }
  if (status == 404) {
    return const RepositoryException(
      code: 'not_found',
      message: AppStrings.notFound,
    );
  }
  return const RepositoryException(
    code: 'unknown',
    message: AppStrings.errorGeneric,
  );
}

Future<T> guardApi<T>(Future<T> Function() body) async {
  try {
    return await body();
  } on RepositoryException {
    rethrow;
  } on DioException catch (error) {
    throw repositoryExceptionFromDio(error);
  } catch (_) {
    throw const RepositoryException(
      code: 'unknown',
      message: AppStrings.errorGeneric,
    );
  }
}
