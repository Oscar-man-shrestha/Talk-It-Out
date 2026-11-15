import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/app/app.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/api/dio_provider.dart';
import 'package:talk_it_out/core/mock/mock_board.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/storage/token_store.dart';
import 'package:talk_it_out/features/invites/join_group_screen.dart';
import 'package:talk_it_out/features/invites/join_with_link.dart';

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first));

String _where(WidgetTester tester) =>
    _router(tester).routerDelegate.currentConfiguration.uri.toString();

Future<void> _pumpApp(
  WidgetTester tester, {
  String? token,
  bool noGroups = false,
}) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // ProviderScope owns the state, so its timers stop when the app closes.
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStoreProvider.overrideWithValue(MemoryTokenStore()..value = token),
        mockControlsProvider.overrideWithValue(
          MockControls(delay: Duration.zero),
        ),
        if (noGroups)
          mockBoardProvider.overrideWith((ref) => MockBoard()..groups.clear()),
      ],
      child: const TalkItOutApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Closes the app so its periodic timers are cancelled.
Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _register(WidgetTester tester) async {
  _router(tester).go('/register');
  await tester.pumpAndSettle();
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), 'Maya Tamang');
  await tester.enterText(fields.at(1), 'maya@example.com');
  await tester.enterText(fields.at(2), 'secret1234');
  await tester.enterText(fields.at(3), 'secret1234');
  final agree = find.byType(Checkbox).last;
  await tester.ensureVisible(agree);
  await tester.tap(agree);
  final submit = find.widgetWithText(FilledButton, 'Create Account');
  await tester.ensureVisible(submit);
  await tester.tap(submit);
  await tester.pumpAndSettle();
}

void main() {
  test('invite codes are found in links and bare codes', () {
    expect(inviteCodeFrom('https://x.app/#/join/abcd2345ef'), 'abcd2345ef');
    expect(inviteCodeFrom('talkitout://app/join/ABCD2345EF'), 'abcd2345ef');
    expect(inviteCodeFrom('  abcd2345ef '), 'abcd2345ef');
    expect(inviteCodeFrom('https://x.app/#/join/abcd2345efg'), isNull);
    expect(inviteCodeFrom('hello'), isNull);
    // 0, 1, i, l, o are never used in codes.
    expect(inviteCodeFrom('abcd1345ef'), isNull);
  });

  testWidgets('a new account gets the welcome tour, then the feed', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _register(tester);
    expect(_where(tester), '/welcome');
    expect(find.text('Welcome, Maya'), findsOneWidget);
    expect(
      find.textContaining('visible to the controller who reviews them'),
      findsOneWidget,
    );
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const ValueKey('welcome-next')));
      await tester.pumpAndSettle();
    }
    expect(find.text('Where do you want to start?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('welcome-explore')));
    await tester.pumpAndSettle();
    expect(_where(tester), startsWith('/feed'));
    await _close(tester);
  });

  testWidgets('skip goes to groups; signing in again never shows it', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _register(tester);
    await tester.tap(find.byKey(const ValueKey('welcome-skip')));
    await tester.pumpAndSettle();
    expect(_where(tester), '/groups');
    await _close(tester);
  });

  testWidgets('an existing account goes straight to groups', (tester) async {
    await _pumpApp(tester, token: 'mock-token');
    expect(_where(tester), '/groups');
    await _close(tester);
  });

  testWidgets('no groups: the empty screen offers create, join and explore', (
    tester,
  ) async {
    await _pumpApp(tester, token: 'mock-token', noGroups: true);
    expect(find.byKey(const ValueKey('groups-empty')), findsOneWidget);
    expect(find.text('Start your first safe space'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('groups-empty-join')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('join-link-field')),
      'not a link',
    );
    await tester.tap(find.byKey(const ValueKey('join-link-go')));
    await tester.pumpAndSettle();
    expect(find.textContaining('does not look like'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('join-link-field')),
      'https://x.app/#/join/abcd2345ef',
    );
    await tester.tap(find.byKey(const ValueKey('join-link-go')));
    await tester.pumpAndSettle();
    // The Join screen opened (pushed over Groups) and explains the bad link.
    expect(find.byType(JoinGroupScreen), findsOneWidget);
    expect(find.textContaining('expired or was turned off'), findsOneWidget);
    await _close(tester);
  });
}
