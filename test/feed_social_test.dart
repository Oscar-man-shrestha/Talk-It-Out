import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/api/dio_provider.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/mock/mock_ids.dart';
import 'package:talk_it_out/core/storage/token_store.dart';
import 'package:talk_it_out/features/discovery/likers_sheet.dart';

ProviderContainer _container() {
  final c = ProviderContainer(
    overrides: [
      tokenStoreProvider.overrideWithValue(
        MemoryTokenStore()..value = 'mock-token',
      ),
      mockControlsProvider.overrideWithValue(
        MockControls(delay: Duration.zero),
      ),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('every demo question shows as many comments as it has', () async {
    final feed = _container().read(feedRepositoryProvider);
    for (final post in (await feed.listPosts()).items) {
      final comments = (await feed.listComments(post.id)).items;
      expect(post.commentCount, comments.length, reason: post.id);
    }
  });

  test('Liked by lists you first and matches the like count', () async {
    final c = _container();
    final page = await c
        .read(discoveryRepositoryProvider)
        .likers(MockIds.retroPost);
    final post = await c
        .read(feedRepositoryProvider)
        .getPost(MockIds.retroPost);
    expect(page.total, post.reactionCount);
    // The demo user liked this one.
    expect(page.items.first.id, MockIds.priya);
    expect(page.items.first.reason, 'You');
    expect(page.items.map((p) => p.id).toSet(), hasLength(page.items.length));
  });

  testWidgets('the sheet lists people and opens nothing for anonymous', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: _container(),
        child: const MaterialApp(
          home: Scaffold(body: LikersSheet(postId: 'q2')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Liked by'), findsOneWidget);
    expect(find.byType(ListTile), findsWidgets);
  });
}
