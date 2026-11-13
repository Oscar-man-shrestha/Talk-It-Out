import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/api/dio_provider.dart';
import 'package:talk_it_out/core/api/endpoints.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/storage/token_store.dart';
import 'package:talk_it_out/features/auth/data/api_auth_repository.dart';
import 'package:talk_it_out/features/auth/data/mock_auth_repository.dart';
import 'package:talk_it_out/features/auth/session_controller.dart';

/// Records requests and answers them from a handler.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;
  final List<RequestOptions> seen = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object body) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

ProviderContainer _mockContainer(MemoryTokenStore tokens) {
  return ProviderContainer(
    overrides: [
      tokenStoreProvider.overrideWithValue(tokens),
      mockControlsProvider.overrideWithValue(
        MockControls(delay: Duration.zero),
      ),
    ],
  );
}

void main() {
  group('delete account (mock)', () {
    test('a wrong password keeps the user signed in', () async {
      final tokens = MemoryTokenStore();
      final container = _mockContainer(tokens);
      addTearDown(container.dispose);
      final session = container.read(sessionProvider.notifier);
      await container.read(sessionProvider.future);
      await session.login(
        email: MockAuthRepository.mockEmail,
        password: MockAuthRepository.mockPassword,
      );

      await expectLater(
        session.deleteAccount(password: 'not-it'),
        throwsA(
          isA<RepositoryException>().having(
            (e) => e.code,
            'code',
            'wrong_password',
          ),
        ),
      );
      expect(container.read(sessionProvider).value, isNotNull);
      expect(tokens.value, isNotNull);
    });

    test('the right password signs out and the account is gone', () async {
      final tokens = MemoryTokenStore();
      final container = _mockContainer(tokens);
      addTearDown(container.dispose);
      final session = container.read(sessionProvider.notifier);
      await container.read(sessionProvider.future);
      await session.register(
        name: 'Temp',
        email: 'temp@example.com',
        password: 'secret123',
      );

      await session.deleteAccount(password: 'secret123');
      expect(container.read(sessionProvider).value, isNull);
      expect(tokens.value, isNull);

      await expectLater(
        session.login(email: 'temp@example.com', password: 'secret123'),
        throwsA(isA<RepositoryException>()),
      );
    });
  });

  group('delete account (API)', () {
    test('sends DELETE /users/me with the password in the body', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://api.test'));
      final adapter = _FakeAdapter((_) => ResponseBody.fromString('', 204));
      dio.httpClientAdapter = adapter;

      await ApiAuthRepository(dio).deleteAccount(password: 'pw-123');

      expect(adapter.seen, hasLength(1));
      expect(adapter.seen.single.method, 'DELETE');
      expect(adapter.seen.single.path, Endpoints.myAccount);
      expect(adapter.seen.single.data, {'password': 'pw-123'});
    });

    test('a 403 wrong_password surfaces as a readable error', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://api.test'));
      dio.httpClientAdapter = _FakeAdapter(
        (_) => _json(403, {
          'error': {
            'code': 'wrong_password',
            'message': 'That password is not correct.',
          },
        }),
      );

      await expectLater(
        ApiAuthRepository(dio).deleteAccount(password: 'typo'),
        throwsA(
          isA<RepositoryException>().having(
            (e) => e.message,
            'message',
            'That password is not correct.',
          ),
        ),
      );
    });
  });
}
