import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/api/dio_provider.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/storage/token_store.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/features/feed/data/post.dart';
import 'package:talk_it_out/features/feed/feed_screen.dart';
import 'package:talk_it_out/features/feed/new_post_screen.dart';

Future<ProviderContainer> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      tokenStoreProvider.overrideWithValue(
        MemoryTokenStore()..value = 'mock-token',
      ),
      mockControlsProvider.overrideWithValue(
        MockControls(delay: Duration.zero),
      ),
    ],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: '/feed',
    routes: [
      GoRoute(
        path: '/feed',
        builder: (_, _) => const FeedScreen(),
        routes: [
          GoRoute(path: 'new', builder: (_, _) => const NewPostScreen()),
        ],
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  router.push('/feed/new');
  await tester.pumpAndSettle();
  return container;
}

Finder _field(String key) => find.descendant(
  of: find.byKey(ValueKey(key)),
  matching: find.byType(EditableText),
);

void main() {
  testWidgets('an empty question shows what is missing and posts nothing', (
    tester,
  ) async {
    final container = await _pumpApp(tester);
    final before =
        (await container.read(feedRepositoryProvider).listPosts()).items.length;

    await tester.tap(find.byKey(const ValueKey('ask-submit')));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.askTitleRequired), findsOneWidget);
    expect(find.text(AppStrings.askTopicRequired), findsOneWidget);
    expect(find.text(AppStrings.askDetailsRequired), findsOneWidget);
    expect(find.text(AppStrings.askPublicNotice), findsOneWidget);
    final after =
        (await container.read(feedRepositoryProvider).listPosts()).items.length;
    expect(after, before);
  });

  testWidgets('a complete question posts title, topic and details', (
    tester,
  ) async {
    final container = await _pumpApp(tester);
    await tester.enterText(_field('ask-title'), 'Should retros be anonymous?');
    await tester.tap(find.byKey(const ValueKey('ask-topic-safety')));
    await tester.enterText(
      _field('ask-details'),
      'Half the team stays quiet in retros.',
    );
    await tester.pump();
    expect(find.text('27/150'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ask-submit')));
    await tester.pumpAndSettle();

    // Back on the feed with a confirmation, and the question is listed.
    expect(find.text(AppStrings.askPosted), findsOneWidget);
    expect(find.text('Should retros be anonymous?'), findsOneWidget);
    final posts =
        (await container.read(feedRepositoryProvider).listPosts()).items;
    final created = posts.firstWhere(
      (p) => p.title == 'Should retros be anonymous?',
    );
    expect(created.topic, 'safety');
    expect(created.content, 'Half the team stays quiet in retros.');
  });

  testWidgets('a short title is refused', (tester) async {
    await _pumpApp(tester);
    await tester.enterText(_field('ask-title'), 'Hm?');
    await tester.tap(find.byKey(const ValueKey('ask-submit')));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.askTitleTooShort), findsOneWidget);
  });

  test('Post JSON with and without title/topic', () {
    final base = {
      'id': 'p1',
      'author': {'id': 'u1', 'name': 'A'},
      'content': 'Body',
      'nsfw_flag': false,
      'other_flags': <String, dynamic>{},
      'reaction_count': 0,
      'my_reaction': null,
      'comment_count': 0,
      'created_at': '2026-11-14T00:00:00Z',
    };
    final old = Post.fromJson(base);
    expect(old.title, isNull);
    expect(old.topic, isNull);
    final q = Post.fromJson({...base, 'title': 'T', 'topic': 'culture'});
    expect(q.title, 'T');
    expect(q.topic, 'culture');
  });
}
