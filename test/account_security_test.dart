import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/app/config.dart';
import 'package:talk_it_out/app/providers.dart';
import 'package:talk_it_out/core/api/dio_provider.dart';
import 'package:talk_it_out/core/api/endpoints.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/storage/token_store.dart';
import 'package:talk_it_out/features/auth/data/mock_auth_repository.dart';
import 'package:talk_it_out/features/auth/session_controller.dart';

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

/// A live-mode container whose server is [handler]; already signed in.
Future<(ProviderContainer, MemoryTokenStore, _FakeAdapter)> _signedIn(
  ResponseBody Function(RequestOptions) handler, {
  String? refresh,
}) async {
  final tokens = MemoryTokenStore()
    ..value = 'access-old'
    ..refreshValue = refresh;
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(useMock: false, apiBaseUrl: 'http://api.test'),
      ),
      tokenStoreProvider.overrideWithValue(tokens),
    ],
  );
  addTearDown(container.dispose);
  final adapter = _FakeAdapter((o) {
    if (o.path == Endpoints.me) {
      return _json(200, {'id': 'u1', 'name': 'Priya', 'email': 'p@x.test'});
    }
    return handler(o);
  });
  container.read(dioProvider).httpClientAdapter = adapter;
  expect(await container.read(sessionProvider.future), isNotNull);
  return (container, tokens, adapter);
}

void main() {
  group('change password', () {
    ResponseBody server(RequestOptions o) {
      if (o.path == Endpoints.changePassword) {
        return _json(200, {'token': 'access-new'});
      }
      if (o.path == Endpoints.refreshTokens) {
        return _json(201, {'refresh_token': 'refresh-new'});
      }
      return _json(404, {});
    }

    test('sends both passwords and keeps this device signed in', () async {
      final (container, tokens, adapter) = await _signedIn(
        server,
        refresh: 'refresh-old',
      );
      await container
          .read(sessionProvider.notifier)
          .changePassword(currentPassword: 'old-pw', newPassword: 'new-pw-1');

      final call = adapter.seen.firstWhere(
        (o) => o.path == Endpoints.changePassword,
      );
      expect(call.data, {
        'current_password': 'old-pw',
        'new_password': 'new-pw-1',
      });
      expect(tokens.value, 'access-new');
      // It had a refresh token (keep session on), so it gets a new one.
      expect(tokens.refreshValue, 'refresh-new');
      expect(container.read(sessionProvider).value, isNotNull);
    });

    test('without a refresh token none is requested', () async {
      final (container, tokens, adapter) = await _signedIn(server);
      await container
          .read(sessionProvider.notifier)
          .changePassword(currentPassword: 'old-pw', newPassword: 'new-pw-1');
      expect(tokens.value, 'access-new');
      expect(tokens.refreshValue, isNull);
      expect(
        adapter.seen.any((o) => o.path == Endpoints.refreshTokens),
        isFalse,
      );
    });

    test('a wrong current password keeps the old tokens', () async {
      final (container, tokens, _) = await _signedIn(
        (_) => _json(403, {
          'error': {
            'code': 'wrong_password',
            'message': 'That password is not correct.',
          },
        }),
        refresh: 'refresh-old',
      );
      await expectLater(
        container
            .read(sessionProvider.notifier)
            .changePassword(currentPassword: 'typo', newPassword: 'new-pw-1'),
        throwsA(isA<RepositoryException>()),
      );
      expect(tokens.value, 'access-old');
      expect(tokens.refreshValue, 'refresh-old');
      expect(container.read(sessionProvider).value, isNotNull);
    });
  });

  group('sign out of all devices', () {
    test('calls the server, then clears this device', () async {
      final (container, tokens, adapter) = await _signedIn(
        (_) => ResponseBody.fromString('', 204),
        refresh: 'refresh-old',
      );
      await container.read(sessionProvider.notifier).logoutAll();
      expect(adapter.seen.any((o) => o.path == Endpoints.logoutAll), isTrue);
      expect(tokens.value, isNull);
      expect(tokens.refreshValue, isNull);
      expect(container.read(sessionProvider).value, isNull);
    });

    test('a server failure keeps this session', () async {
      final (container, tokens, _) = await _signedIn(
        (_) => _json(500, {
          'error': {'code': 'internal', 'message': 'Something went wrong.'},
        }),
      );
      await expectLater(
        container.read(sessionProvider.notifier).logoutAll(),
        throwsA(isA<RepositoryException>()),
      );
      expect(tokens.value, 'access-old');
      expect(container.read(sessionProvider).value, isNotNull);
    });
  });

  test('mock change password checks the current password', () async {
    final repo = MockAuthRepository(MockControls(delay: Duration.zero));
    await repo.login(
      email: MockAuthRepository.mockEmail,
      password: MockAuthRepository.mockPassword,
    );
    await expectLater(
      repo.changePassword(currentPassword: 'nope', newPassword: 'whatever1'),
      throwsA(isA<RepositoryException>()),
    );
    await repo.changePassword(
      currentPassword: MockAuthRepository.mockPassword,
      newPassword: 'whatever1',
    );
    final session = await repo.login(
      email: MockAuthRepository.mockEmail,
      password: 'whatever1',
    );
    expect(session.user.email, MockAuthRepository.mockEmail);
  });
}
