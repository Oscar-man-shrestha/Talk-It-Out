import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/features/auth/data/mock_auth_repository.dart';
import 'package:talk_it_out/app/config.dart';
import 'package:talk_it_out/app/providers.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/api/dio_provider.dart';
import 'package:talk_it_out/core/api/endpoints.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/storage/token_store.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/features/auth/data/api_auth_repository.dart';
import 'package:talk_it_out/features/auth/login_screen.dart';

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

Future<ProviderContainer> _pumpLogin(
  WidgetTester tester, {
  required AppConfig config,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(config),
      tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
      mockControlsProvider.overrideWithValue(
        MockControls(delay: Duration.zero),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: LoginScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  test('API: POST /auth/google with the ID token', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'));
    final adapter = _FakeAdapter(
      (_) => ResponseBody.fromString(
        jsonEncode({
          'token': 'access-g',
          'user': {'id': 'u9', 'name': 'Maya Lin', 'email': 'maya@gmail.com'},
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
    dio.httpClientAdapter = adapter;
    final session = await ApiAuthRepository(dio)
        .signInWithGoogle(idToken: 'google-id-token');
    expect(adapter.seen.single.path, Endpoints.google);
    expect(adapter.seen.single.data, {'id_token': 'google-id-token'});
    expect(session.token, 'access-g');
    expect(session.user.name, 'Maya Lin');
  });

  testWidgets('demo build hides Google: there is no Google account behind it', (
    tester,
  ) async {
    await _pumpLogin(
      tester,
      config: const AppConfig(useMock: true, apiBaseUrl: 'http://api.test'),
    );
    expect(find.text(AppStrings.continueWithGoogle), findsNothing);
  });

  testWidgets('live build without GOOGLE_CLIENT_ID hides the button', (
    tester,
  ) async {
    await _pumpLogin(
      tester,
      config: const AppConfig(useMock: false, apiBaseUrl: 'http://api.test'),
    );
    expect(find.text(AppStrings.continueWithGoogle), findsNothing);
    expect(find.text(AppStrings.orDivider), findsNothing);
  });

  test('demo: a Google token signs you in as yourself', () async {
    String part(Map<String, Object> m) =>
        base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
    final token =
        '${part({'alg': 'RS256'})}.${part({'email': 'Maya.Lin@Gmail.com', 'name': 'Maya Lin'})}.sig';
    final auth = MockAuthRepository(MockControls(delay: Duration.zero));
    final session = await auth.signInWithGoogle(idToken: token);
    expect(session.user.name, 'Maya Lin');
    expect(session.user.email, 'maya.lin@gmail.com');
    // Signing in again finds the same demo account.
    final again = await auth.signInWithGoogle(idToken: token);
    expect(again.user.email, 'maya.lin@gmail.com');
  });
}
