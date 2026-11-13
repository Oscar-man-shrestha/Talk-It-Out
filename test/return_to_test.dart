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

String _where(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first))
        .routerDelegate
        .currentConfiguration
        .uri
        .toString();

void main() {
  testWidgets('a signed-out visitor lands on the page they opened after '
      'signing in', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
          mockControlsProvider.overrideWithValue(
            MockControls(delay: Duration.zero),
          ),
        ],
        child: const TalkItOutApp(),
      ),
    );
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.byType(Navigator).first)).go('/feed');
    await tester.pumpAndSettle();
    expect(_where(tester), '/login?from=%2Ffeed');

    // Mock builds start filled with the sample account.
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.loginAction));
    await tester.pumpAndSettle();
    expect(_where(tester), '/feed');
  });

  testWidgets('?from= never leads to another site or back to an auth page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
          mockControlsProvider.overrideWithValue(
            MockControls(delay: Duration.zero),
          ),
        ],
        child: const TalkItOutApp(),
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Navigator).first))
        .go('/login?from=%2F%2Fevil.example%2Fx');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.loginAction));
    await tester.pumpAndSettle();
    expect(_where(tester), '/groups');
  });
}
