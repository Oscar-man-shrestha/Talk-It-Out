import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/app/app.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/app/router.dart';
import 'package:talk_it_out/core/api/dio_provider.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/mock/mock_ids.dart';
import 'package:talk_it_out/core/storage/token_store.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/features/feed/feed_screen.dart';

/// Run 117: the heart on a feed card likes the question (it used to only
/// open it), and upvoting your own answer explains why it cannot be done.
Future<ProviderContainer> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1.0;
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
      ],
      child: const TalkItOutApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(TalkItOutApp)));
}

void main() {
  testWidgets('the heart on a feed card toggles the like', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
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
        ],
        child: const MaterialApp(home: FeedScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FeedScreen)),
    );
    await tester.tap(find.byKey(const ValueKey('feed-tab-1')));
    await tester.pumpAndSettle();

    const postId = MockIds.dashboardPost;
    final heart = find.byKey(const ValueKey('card-like-$postId'));
    await tester.scrollUntilVisible(
      heart,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    // Let the cards finish their entrance, then make sure the heart is
    // fully on screen before tapping it.
    await tester.pumpAndSettle();
    await tester.ensureVisible(heart);
    await tester.pumpAndSettle();
    final repo = container.read(feedRepositoryProvider);
    final before = await repo.getPost(postId);

    await tester.tap(heart);
    await tester.pumpAndSettle();
    final liked = await repo.getPost(postId);
    expect(liked.reactionCount, before.reactionCount + 1);
    expect(liked.myReaction, isNotNull);
    expect(
      find.descendant(of: heart, matching: find.byIcon(Icons.favorite)),
      findsOneWidget,
    );

    await tester.tap(heart);
    await tester.pumpAndSettle();
    final unliked = await repo.getPost(postId);
    expect(unliked.reactionCount, before.reactionCount);
    expect(unliked.myReaction, isNull);
    expect(
      find.descendant(of: heart, matching: find.byIcon(Icons.favorite_border)),
      findsOneWidget,
    );
  });

  testWidgets('upvoting your own answer says why it cannot', (tester) async {
    final container = await _pumpApp(tester);
    final repo = container.read(feedRepositoryProvider);
    const postId = MockIds.dashboardPost;
    final mine = await repo.addComment(postId, content: 'My own answer.');

    container.read(routerProvider).go('/feed/$postId');
    await tester.pumpAndSettle();
    final vote = find.byKey(ValueKey('vote-${mine.id}'));
    await tester.scrollUntilVisible(
      vote,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(vote);
    await tester.pump();
    expect(find.text(AppStrings.cannotUpvoteOwnAnswer), findsOneWidget);
    final after = (await repo.listComments(postId)).items
        .firstWhere((c) => c.id == mine.id);
    expect(after.voteCount, 0);
  });
}
