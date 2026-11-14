import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/app/app.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/api/dio_provider.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/storage/token_store.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/features/auth/data/mock_auth_repository.dart';

Future<void> _pumpApp(WidgetTester tester, {bool signedIn = false}) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final token = MemoryTokenStore();
  if (signedIn) token.value = 'mock-token';
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStoreProvider.overrideWithValue(token),
        mockControlsProvider.overrideWithValue(
          MockControls(delay: Duration.zero),
        ),
      ],
      child: const TalkItOutApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void _go(WidgetTester tester, String location) {
  GoRouter.of(tester.element(find.byType(NavigationBar, skipOffstage: false)))
      .go(location);
}

Finder get _signIn => find.widgetWithText(FilledButton, AppStrings.loginAction);

void main() {
  testWidgets('log in uses the typed account and never substitutes one', (
    tester,
  ) async {
    await _pumpApp(tester);
    // Mock builds start filled with the documented sample account.
    final fields = find.byType(TextField);
    expect(
      tester.widget<TextField>(fields.at(0)).controller!.text,
      MockAuthRepository.mockEmail,
    );

    // An unknown email used to be silently swapped for the sample account.
    await tester.enterText(fields.at(0), 'stranger@elsewhere.org');
    await tester.tap(_signIn);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.wrongLogin), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    // So did a wrong password.
    await tester.enterText(fields.at(0), MockAuthRepository.mockEmail);
    await tester.enterText(fields.at(1), 'not-the-password');
    await tester.tap(_signIn);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.wrongLogin), findsOneWidget);

    await tester.enterText(fields.at(1), MockAuthRepository.mockPassword);
    await tester.tap(_signIn);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('alerts render repository records and nothing private', (
    tester,
  ) async {
    await _pumpApp(tester, signedIn: true);
    _go(tester, '/notifications');
    await tester.pumpAndSettle();

    expect(
      find.text(AppStrings.messagePendingReview('Dashboard improvements')),
      findsOneWidget,
    );
    expect(
      find.text(AppStrings.messageRejected('Making NLP notes')),
      findsNWidgets(2),
    );
    expect(find.text('3 new'), findsOneWidget);
    expect(find.text('All (4)'), findsOneWidget);

    // No rewrite preview or apply, no rejection reason or controller note,
    // and none of the old invented cards.
    for (final banned in [
      'Inspect Diff',
      'Apply',
      'Controller Note',
      'Off-topic',
      'Elena',
      'David Chen',
      'hash:',
    ]) {
      expect(find.textContaining(banned), findsNothing);
    }

    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();
    expect(find.text('0 new'), findsOneWidget);
  });

  testWidgets('profile shows the signed-in account, not a sample person', (
    tester,
  ) async {
    await _pumpApp(tester, signedIn: true);
    _go(tester, '/profile');
    await tester.pumpAndSettle();

    expect(find.text('Priya'), findsWidgets);
    expect(find.text(MockAuthRepository.mockEmail), findsOneWidget);
    for (final invented in [
      'Priya Sharma',
      'Stanford',
      'Ex-Google',
      '1,420+',
      '(she/her)',
      '94%',
      // Run 089: no made-up anonymity ID or AI score on the profile.
      'DISPLAY ID',
      'Rotate',
      '12h left',
      'AI CLARITY',
    ]) {
      expect(find.textContaining(invented), findsNothing);
    }
    // Anonymous messages carry no ID: the card says what others see.
    final card = find.byKey(const ValueKey('anonymity-card'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text(AppStrings.anonymousUser)),
      findsOneWidget,
    );
  });
}
