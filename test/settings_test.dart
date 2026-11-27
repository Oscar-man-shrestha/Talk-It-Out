import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/app/app.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/app/router.dart';
import 'package:talk_it_out/core/api/dio_provider.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/storage/token_store.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/features/premium/chat_prefs.dart';

Future<ProviderContainer> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStoreProvider.overrideWithValue(
          MemoryTokenStore()..value = 'mock-token',
        ),
        mockControlsProvider.overrideWithValue(
          MockControls(delay: Duration.zero),
        ),
        chatPrefsStorageProvider.overrideWithValue(null),
      ],
      child: const TalkItOutApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(TalkItOutApp)));
}

void main() {
  testWidgets('profile is about you; account settings live in Settings', (
    tester,
  ) async {
    final container = await _pumpApp(tester);
    container.read(routerProvider).go('/profile');
    await tester.pumpAndSettle();

    // The profile no longer carries account actions.
    expect(find.text(AppStrings.deleteAccount), findsNothing);
    expect(find.text(AppStrings.changePassword), findsNothing);

    await tester.tap(find.byKey(const ValueKey('profile-settings')));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsWidgets);
    expect(find.byKey(const ValueKey('settings-open-profile')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-blocked')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(AppStrings.deleteAccount),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(AppStrings.changePassword), findsOneWidget);
    expect(find.text(AppStrings.logoutAll), findsOneWidget);
  });
}
