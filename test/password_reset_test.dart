import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/app/config.dart';
import 'package:talk_it_out/app/providers.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/api/dio_provider.dart';
import 'package:talk_it_out/core/api/endpoints.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/storage/token_store.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/features/auth/data/api_auth_repository.dart';
import 'package:talk_it_out/features/auth/data/mock_auth_repository.dart';
import 'package:talk_it_out/features/auth/forgot_password_screen.dart';
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

MockAuthRepository _mockRepo() =>
    MockAuthRepository(MockControls(delay: Duration.zero));

void main() {
  group('password reset (mock)', () {
    test('code first, then the token sets a new password', () async {
      final repo = _mockRepo();
      await repo.requestPasswordReset(email: MockAuthRepository.mockEmail);
      final token = await repo.verifyResetCode(
        email: MockAuthRepository.mockEmail,
        code: MockAuthRepository.mockResetCode,
      );
      await repo.confirmPasswordReset(
        email: MockAuthRepository.mockEmail,
        resetToken: token,
        newPassword: 'brand-new-pass',
      );
      await expectLater(
        repo.login(
          email: MockAuthRepository.mockEmail,
          password: MockAuthRepository.mockPassword,
        ),
        throwsA(isA<RepositoryException>()),
      );
      final session = await repo.login(
        email: MockAuthRepository.mockEmail,
        password: 'brand-new-pass',
      );
      expect(session.user.email, MockAuthRepository.mockEmail);
    });

    test('unknown email, wrong code and bad token are refused', () async {
      final repo = _mockRepo();
      await expectLater(
        repo.requestPasswordReset(email: 'nobody@example.com'),
        throwsA(
          isA<RepositoryException>().having(
            (e) => e.code,
            'code',
            'no_account',
          ),
        ),
      );
      await expectLater(
        repo.verifyResetCode(
          email: MockAuthRepository.mockEmail,
          code: '000000',
        ),
        throwsA(
          isA<RepositoryException>().having(
            (e) => e.message,
            'message',
            AppStrings.resetCodeInvalid,
          ),
        ),
      );
      await expectLater(
        repo.confirmPasswordReset(
          email: MockAuthRepository.mockEmail,
          resetToken: 'made-up',
          newPassword: 'brand-new-pass',
        ),
        throwsA(isA<RepositoryException>()),
      );
    });
  });

  group('password reset (API)', () {
    test('sends the documented three requests', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://api.test'));
      final adapter = _FakeAdapter((o) {
        if (o.path == Endpoints.passwordReset) {
          return _json(202, {'status': 'sent', 'expires_in_minutes': 15});
        }
        if (o.path == Endpoints.passwordResetVerify) {
          return _json(200, {'reset_token': 'a' * 64});
        }
        return ResponseBody.fromString('', 204);
      });
      dio.httpClientAdapter = adapter;
      final repo = ApiAuthRepository(dio);

      await repo.requestPasswordReset(email: 'p@example.com');
      final token = await repo.verifyResetCode(
        email: 'p@example.com',
        code: '123456',
      );
      await repo.confirmPasswordReset(
        email: 'p@example.com',
        resetToken: token,
        newPassword: 'new-password',
      );

      expect(adapter.seen.map((o) => o.path), [
        Endpoints.passwordReset,
        Endpoints.passwordResetVerify,
        Endpoints.passwordResetConfirm,
      ]);
      expect(adapter.seen[1].data, {
        'email': 'p@example.com',
        'code': '123456',
      });
      expect(adapter.seen[2].data, {
        'email': 'p@example.com',
        'reset_token': 'a' * 64,
        'new_password': 'new-password',
      });
    });

    test('a 400 invalid_code shows the server message', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
        ..httpClientAdapter = _FakeAdapter(
          (_) => _json(400, {
            'error': {
              'code': 'invalid_code',
              'message': 'That code is not right. 4 tries left.',
            },
          }),
        );
      await expectLater(
        ApiAuthRepository(dio)
            .verifyResetCode(email: 'p@example.com', code: '999999'),
        throwsA(
          isA<RepositoryException>().having(
            (e) => e.message,
            'message',
            'That code is not right. 4 tries left.',
          ),
        ),
      );
    });
  });

  group('keep active session', () {
    Future<MemoryTokenStore> signIn({required bool keepSession}) async {
      final tokens = MemoryTokenStore();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(useMock: false, apiBaseUrl: 'http://api.test'),
          ),
          tokenStoreProvider.overrideWithValue(tokens),
        ],
      );
      addTearDown(container.dispose);
      container.read(dioProvider).httpClientAdapter = _FakeAdapter((o) {
        if (o.path == Endpoints.login) {
          return _json(200, {
            'token': 'access-1',
            'user': {'id': 'u1', 'name': 'Priya', 'email': 'p@example.com'},
          });
        }
        if (o.path == Endpoints.refreshTokens) {
          return _json(201, {
            'refresh_token': 'refresh-1',
            'expires_at': '2026-12-13T00:00:00Z',
          });
        }
        return _json(401, {});
      });
      await container.read(sessionProvider.future);
      await container
          .read(sessionProvider.notifier)
          .login(
            email: 'p@example.com',
            password: 'secret123',
            keepSession: keepSession,
          );
      expect(tokens.value, 'access-1');
      return tokens;
    }

    test('on: a refresh token is kept for long sessions', () async {
      expect((await signIn(keepSession: true)).refreshValue, 'refresh-1');
    });

    test(
      'off: no refresh token, so the session ends with the access token',
      () async {
        expect((await signIn(keepSession: false)).refreshValue, isNull);
      },
    );
  });

  testWidgets('Forgot password screen resets and returns to log in', (
    tester,
  ) async {
    // Tall enough that the whole form (and the mock hint at the bottom of
    // the list) is built.
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/forgot-password',
      routes: [
        GoRoute(
          path: '/forgot-password',
          builder: (_, _) => const ForgotPasswordScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (_, _) => const Scaffold(body: Text('LOGIN PAGE')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
          mockControlsProvider.overrideWithValue(
            MockControls(delay: Duration.zero),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.resetTitle), findsOneWidget);
    expect(find.text(AppStrings.resetStep(1)), findsOneWidget);
    await tester.tap(find.text(AppStrings.resetSendCode));
    await tester.pump();
    expect(find.text(AppStrings.enterValidEmail), findsOneWidget);

    // An email with no account gets no code.
    await tester.enterText(
      find.byKey(const ValueKey('reset-email')).first,
      'nobody@example.com',
    );
    await tester.tap(find.text(AppStrings.resetSendCode));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.resetNoAccount), findsOneWidget);
    expect(find.text(AppStrings.resetCreateAccount), findsOneWidget);
    expect(find.byKey(const ValueKey('reset-code')), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('reset-email')).first,
      MockAuthRepository.mockEmail,
    );
    await tester.tap(find.text(AppStrings.resetSendCode));
    await tester.pump();
    await tester.pump();
    // Step 2: only the code, no password field yet.
    expect(find.text(AppStrings.resetCodeTitle), findsOneWidget);
    expect(find.text(AppStrings.resetStep(2)), findsOneWidget);
    expect(find.byKey(const ValueKey('reset-password')), findsNothing);
    expect(find.text(AppStrings.resetMockHint), findsOneWidget);
    expect(find.text(AppStrings.resetResendIn(60)), findsOneWidget);

    final codeField = find.descendant(
      of: find.byKey(const ValueKey('reset-code')),
      matching: find.byType(TextField),
    );
    await tester.enterText(codeField, '000000');
    await tester.pump();
    await tester.pump();
    expect(find.text(AppStrings.resetCodeInvalid), findsOneWidget);
    expect(find.byKey(const ValueKey('reset-password')), findsNothing);

    // Six digits submit by themselves.
    await tester.enterText(codeField, MockAuthRepository.mockResetCode);
    await tester.pump();
    await tester.pump();
    expect(find.text(AppStrings.resetPasswordTitle), findsOneWidget);
    expect(find.text(AppStrings.resetStep(3)), findsOneWidget);

    Finder field(String key) => find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(TextField),
    );
    await tester.enterText(field('reset-password'), 'brand-new-pass');
    await tester.enterText(field('reset-password-confirm'), 'different-pass');
    await tester.tap(find.text(AppStrings.resetConfirm));
    await tester.pump();
    expect(find.text(AppStrings.resetPasswordsDiffer), findsOneWidget);

    await tester.enterText(field('reset-password-confirm'), 'brand-new-pass');
    await tester.tap(find.text(AppStrings.resetConfirm));
    await tester.pumpAndSettle();
    expect(find.text('LOGIN PAGE'), findsOneWidget);
    expect(find.text(AppStrings.resetDone), findsOneWidget);
  });
}
