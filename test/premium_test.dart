import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/app/app.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/app/router.dart';
import 'package:talk_it_out/app/theme.dart';
import 'package:talk_it_out/core/api/dio_provider.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/mock/mock_ids.dart';
import 'package:talk_it_out/core/storage/token_store.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/features/premium/data/billing_repository.dart';
import 'package:talk_it_out/features/premium/data/premium_models.dart';
import 'package:talk_it_out/features/premium/group_insights_screen.dart';
import 'package:talk_it_out/features/premium/premium_providers.dart';
import 'package:talk_it_out/features/premium/store_purchases.dart';

List<Override> _mockOverrides() => [
  tokenStoreProvider.overrideWithValue(
    MemoryTokenStore()..value = 'mock-token',
  ),
  mockControlsProvider.overrideWithValue(MockControls(delay: Duration.zero)),
];

/// Serves fixed insights (for states the mock does not produce).
class _FixedInsights extends MockBillingRepository {
  _FixedInsights(this.value) : super(MockControls(delay: Duration.zero));

  final GroupInsights value;

  @override
  Future<GroupInsights> insights(String groupId) async => value;
}

void main() {
  group('models', () {
    test('entitlements parse, and unknown fields are tolerated', () {
      final e = Entitlements.fromJson({
        'premium': true,
        'status': 'cancelled',
        'provider': 'revenuecat',
        'expires_at': '2026-12-26T10:00:00.000Z',
        'will_renew': false,
        'something_new': 1,
      });
      expect(e.premium, isTrue);
      expect(e.status, 'cancelled');
      expect(e.willRenew, isFalse);
      expect(e.expiresAt, DateTime.utc(2026, 12, 26, 10));
      expect(Entitlements.fromJson({}).premium, isFalse);
    });

    test('insights parse, with breakdowns null for small groups', () {
      final i = GroupInsights.fromJson({
        'window_days': 14,
        'member_count': 3,
        'breakdowns_available': false,
        'messages': 4,
        'daily': [
          {'date': '2026-11-25', 'count': 3},
          {'date': '2026-11-26', 'count': 1},
        ],
        'pending': 1,
        'accepted': 2,
        'rejected': 0,
        'review_median_minutes': 12,
        'participants': null,
        'anonymous_messages': null,
        'busiest_hours': null,
        'top_words': [
          {'word': 'deadline', 'count': 2},
        ],
      });
      expect(i.daily, hasLength(2));
      expect(i.daily.first.count, 3);
      expect(i.participants, isNull);
      expect(i.busiestHours, isNull);
      expect(i.topWords.single, ('deadline', 2));
    });
  });

  test('the store key follows the platform; the web never sells', () {
    String key(TargetPlatform p, {bool web = false}) =>
        storeKeyFor(appleKey: 'a', googleKey: 'g', platform: p, web: web);
    expect(key(TargetPlatform.iOS), 'a');
    expect(key(TargetPlatform.android), 'g');
    expect(key(TargetPlatform.android, web: true), '');
    expect(key(TargetPlatform.windows), '');
  });

  test(
    'in the demo, buying Premium turns it on (the server decides)',
    () async {
      final container = ProviderContainer(overrides: _mockOverrides());
      addTearDown(container.dispose);
      expect(
        (await container.read(entitlementsProvider.future)).premium,
        isFalse,
      );
      final store = container.read(storePurchasesProvider);
      expect(store, isA<MockStorePurchases>());
      expect(await store.buy(), PurchaseOutcome.purchased);
      await container.read(entitlementsProvider.notifier).syncNow();
      expect(container.read(isPremiumProvider), isTrue);
    },
  );

  testWidgets('Premium screen: price, disclosures, and subscribing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(overrides: _mockOverrides(), child: const TalkItOutApp()),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TalkItOutApp)),
    );
    container.read(routerProvider).go('/premium');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('premium-price')), findsOneWidget);
    // The plans, how to pay, then the disclosures further down the page.
    expect(find.byKey(const ValueKey('plan-free')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('premium-restore')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('how-you-pay')), findsOneWidget);
    expect(find.text(AppStrings.premiumDisclosure), findsOneWidget);
    expect(find.text(AppStrings.premiumTerms), findsOneWidget);
    expect(find.text(AppStrings.premiumPrivacy), findsOneWidget);
    expect(find.byKey(const ValueKey('premium-restore')), findsOneWidget);
    expect(find.text(AppStrings.premiumFreeTitle), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('premium-subscribe')),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('premium-subscribe')));
    await tester.pumpAndSettle();
    // Back to the top, where the "you have Premium" card replaces the price.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.planYourPlan), findsOneWidget);
    expect(find.byKey(const ValueKey('premium-active')), findsOneWidget);
    expect(find.text(AppStrings.premiumYouHave), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Insights without Premium show the teaser', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _mockOverrides(),
        child: MaterialApp(
          theme: lightTheme,
          home: const GroupInsightsScreen(groupId: MockIds.dashboardGroup),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('insights-teaser')), findsOneWidget);
    expect(find.text(AppStrings.premiumUnlock), findsOneWidget);
  });

  testWidgets('small groups never show participation or timing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final small = GroupInsights(
      windowDays: 14,
      memberCount: 3,
      breakdownsAvailable: false,
      messages: 4,
      daily: [
        for (var i = 0; i < 14; i++)
          DayCount(DateTime(2026, 11, 13 + i), i % 3),
      ],
      pending: 1,
      accepted: 2,
      rejected: 1,
      reviewMedianMinutes: 75,
      topWords: const [('deadline', 2)],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._mockOverrides(),
          billingRepositoryProvider.overrideWithValue(_FixedInsights(small)),
        ],
        child: MaterialApp(
          theme: lightTheme,
          home: const GroupInsightsScreen(groupId: MockIds.dashboardGroup),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('insights-small-group')), findsOneWidget);
    expect(find.text(AppStrings.insightsParticipants), findsNothing);
    expect(find.text(AppStrings.insightsAnonymous), findsNothing);
    expect(find.text('1 h 15 min'), findsOneWidget);
    expect(find.text('deadline · 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
