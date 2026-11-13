import 'dart:async';
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
import 'package:talk_it_out/core/mock/mock_board.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/mock/mock_ids.dart';
import 'package:talk_it_out/core/models/enums.dart';
import 'package:talk_it_out/core/storage/token_store.dart';
import 'package:talk_it_out/core/utils/image_download.dart';
import 'package:talk_it_out/features/auth/auth_events.dart';
import 'package:talk_it_out/features/groups/data/mock_group_repository.dart';
import 'package:talk_it_out/features/groups/data/mock_message_bridge.dart';

/// Answers requests from a handler and records every path it saw.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  final List<RequestOptions> seen = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
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

void main() {
  group('token refresh', () {
    test(
      'concurrent callers share one exchange and rotate both tokens',
      () async {
        final tokens = MemoryTokenStore()
          ..value = 'old-access'
          ..refreshValue = 'old-refresh';
        final gate = Completer<void>();
        final adapter = _FakeAdapter((options) async {
          await gate.future;
          expect(options.data, {'refresh_token': 'old-refresh'});
          return _json(200, {
            'token': 'new-access',
            'refresh_token': 'new-refresh',
            'expires_at': '2026-12-13T00:00:00Z',
          });
        });
        final refresher = TokenRefresher(
          Dio()..httpClientAdapter = adapter,
          tokens,
        );

        final first = refresher.refresh();
        final second = refresher.refresh();
        gate.complete();

        expect(await first, 'new-access');
        expect(await second, 'new-access');
        // Spending the same refresh token twice would revoke the whole family.
        expect(adapter.seen, hasLength(1));
        expect(tokens.value, 'new-access');
        expect(tokens.refreshValue, 'new-refresh');
      },
    );

    test('no refresh token or a rejected one gives null', () async {
      final adapter = _FakeAdapter((_) async => _json(401, {}));
      final dio = Dio()..httpClientAdapter = adapter;
      expect(await TokenRefresher(dio, MemoryTokenStore()).refresh(), isNull);
      expect(adapter.seen, isEmpty);

      final tokens = MemoryTokenStore()..refreshValue = 'revoked';
      expect(await TokenRefresher(dio, tokens).refresh(), isNull);
    });

    test('a 401 is refreshed and the request replayed once', () async {
      final tokens = MemoryTokenStore()
        ..value = 'expired'
        ..refreshValue = 'r1';
      var signedOut = false;
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(useMock: false, apiBaseUrl: 'http://api.test'),
          ),
          tokenStoreProvider.overrideWithValue(tokens),
        ],
      );
      addTearDown(container.dispose);
      container.read(authEventsProvider).onUnauthorized = () =>
          signedOut = true;
      final adapter = _FakeAdapter((options) async {
        if (options.path == Endpoints.refresh) {
          return _json(200, {'token': 'fresh', 'refresh_token': 'r2'});
        }
        final auth = options.headers['Authorization'];
        return auth == 'Bearer fresh'
            ? _json(200, {'id': 'u1', 'name': 'Priya'})
            : _json(401, {
                'error': {'code': 'unauthorized', 'message': 'Expired.'},
              });
      });
      final dio = container.read(dioProvider)..httpClientAdapter = adapter;

      final response = await dio.get<dynamic>(Endpoints.me);
      expect(response.statusCode, 200);
      expect(tokens.value, 'fresh');
      expect(tokens.refreshValue, 'r2');
      expect(signedOut, isFalse);
    });
  });

  group('controller hand-over (D4)', () {
    MockGroupRepository repo(MockBoard board) => MockGroupRepository(
      MockControls(delay: Duration.zero),
      board,
      MockMessageBridge(),
    );

    test(
      'a leaving controller hands the group to the earliest member',
      () async {
        final board = MockBoard();
        final groups = repo(board);
        final before = await groups.listMembers(MockIds.dashboardGroup);
        final heir = before.items.firstWhere((m) => m.userId != MockIds.priya);

        await groups.leaveGroup(MockIds.dashboardGroup);

        final after = board.membersByGroup[MockIds.dashboardGroup]!;
        expect(after.any((m) => m.userId == MockIds.priya), isFalse);
        expect(
          after.firstWhere((m) => m.userId == heir.userId).role,
          GroupRole.controller,
        );
        expect(
          after.where((m) => m.role == GroupRole.controller),
          hasLength(1),
        );
      },
    );

    test('the only member cannot leave', () async {
      final board = MockBoard();
      final groups = repo(board);
      final created = await groups.createGroup(agenda: 'Solo room');
      await expectLater(
        groups.leaveGroup(created.id),
        throwsA(
          isA<RepositoryException>().having(
            (e) => e.code,
            'code',
            'last_member',
          ),
        ),
      );
    });
  });

  test('preset pictures are requested as JPEG, without credentials', () async {
    final adapter = _FakeAdapter(
      (_) async => ResponseBody.fromBytes([0xFF, 0xD8, 0xFF, 0xE0], 200),
    );
    final bytes = await downloadPresetImage(
      'https://images.unsplash.com/photo-1?auto=format&fit=crop&w=256',
      client: Dio()..httpClientAdapter = adapter,
    );
    expect(bytes, [0xFF, 0xD8, 0xFF, 0xE0]);
    final uri = adapter.seen.single.uri;
    expect(uri.queryParameters['fm'], 'jpg');
    expect(uri.queryParameters.containsKey('auto'), isFalse);
    expect(uri.queryParameters['w'], '256');
    expect(adapter.seen.single.headers.containsKey('Authorization'), isFalse);
  });
}
