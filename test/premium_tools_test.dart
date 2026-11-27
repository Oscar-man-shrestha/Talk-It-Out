import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/app/app.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/app/router.dart';
import 'package:talk_it_out/app/theme.dart';
import 'package:talk_it_out/core/api/dio_provider.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/storage/token_store.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/core/ui/emoji_text.dart';
import 'package:talk_it_out/features/groups/data/published_message.dart';
import 'package:talk_it_out/features/premium/chat_prefs.dart';
import 'package:talk_it_out/features/premium/data/billing_repository.dart';
import 'package:talk_it_out/features/premium/plan_compare.dart';
import 'package:talk_it_out/features/premium/premium_providers.dart';

final _premiumRepo = MockBillingRepository(MockControls(delay: Duration.zero))
  ..grant();

Future<ProviderContainer> _pumpApp(
  WidgetTester tester, {
  bool premium = true,
}) async {
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
        if (premium) billingRepositoryProvider.overrideWithValue(_premiumRepo),
      ],
      child: const TalkItOutApp(),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(TalkItOutApp)),
  );
  await container.read(entitlementsProvider.future);
  return container;
}

void main() {
  testWidgets('the heart reaction is drawn in red, not as a black glyph', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: EmojiGlyph('❤️', size: 20))),
    );
    final icon = tester.widget<Icon>(find.byIcon(Icons.favorite));
    expect(icon.color, isNot(Colors.black));
    expect(find.text('❤️'), findsNothing);
  });

  testWidgets('plans compare Free and Premium and say how to pay', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: Column(children: [PlanCompare(premium: false), HowYouPay()]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('plan-free')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-premium')), findsOneWidget);
    expect(find.text(AppStrings.planYourPlan), findsOneWidget);
    expect(find.text('UPI'), findsOneWidget);
    expect(
      find.text('Chat themes: your own bubble colour and wallpaper'),
      findsOneWidget,
    );
  });

  testWidgets('starring keeps published text only, and lists it', (
    tester,
  ) async {
    final container = await _pumpApp(tester);
    final message = PublishedMessage(
      id: 'pm-star',
      groupId: 'g1',
      text: 'The deadline moved to Friday.',
      publishedAt: DateTime.utc(2026, 11, 26, 10),
    );
    await container
        .read(starredProvider.notifier)
        .toggle(message, AppStrings.anonymousUser);
    expect(
      container.read(starredProvider).single.sender,
      AppStrings.anonymousUser,
    );

    container.read(routerProvider).go('/starred');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('starred-pm-star')), findsOneWidget);
    expect(find.text('The deadline moved to Friday.'), findsOneWidget);

    await container.read(starredProvider.notifier).toggle(message, '');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('starred-empty')), findsOneWidget);
  });

  testWidgets('chat theme applies only with Premium', (tester) async {
    final container = await _pumpApp(tester);
    container.read(routerProvider).go('/chat-theme');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('accent-ocean')));
    await tester.tap(find.byKey(const ValueKey('wallpaper-grid')));
    await tester.pumpAndSettle();
    final theme = container.read(chatThemeProvider);
    expect(theme.accent, BubbleAccent.ocean);
    expect(theme.wallpaper, ChatWallpaperStyle.grid);
  });

  testWidgets('free users see the tools locked, with a way to Premium', (
    tester,
  ) async {
    final container = await _pumpApp(tester, premium: false);
    expect(container.read(chatThemeProvider), defaultChatTheme);
    container.read(routerProvider).go('/starred');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('locked-get-premium')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('locked-get-premium')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('plan-premium')), findsOneWidget);
  });
}
