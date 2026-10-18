import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/core/api/api_guard.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';

void main() {
  test('API errors use the human-readable message', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/groups'),
      response: Response(
        requestOptions: RequestOptions(path: '/groups'),
        statusCode: 403,
        data: {
          'error': {'code': 'forbidden', 'message': 'Not a member'},
        },
      ),
    );
    final mapped = repositoryExceptionFromDio(error);
    expect(mapped.message, 'Not a member');
    expect(mapped.code, 'forbidden');
  });

  test('missing error body falls back to a safe string', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/missing'),
      response: Response(
        requestOptions: RequestOptions(path: '/missing'),
        statusCode: 404,
      ),
    );
    expect(repositoryExceptionFromDio(error).message, AppStrings.notFound);
  });
}
