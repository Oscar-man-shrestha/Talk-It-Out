import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/api/dio_provider.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/mock/mock_ids.dart';
import 'package:talk_it_out/core/models/page_result.dart';
import 'package:talk_it_out/core/storage/token_store.dart';
import 'package:talk_it_out/features/feed/data/comment.dart';
import 'package:talk_it_out/features/feed/data/feed_repository.dart';
import 'package:talk_it_out/features/feed/data/mock_feed_repository.dart';
import 'package:talk_it_out/features/feed/data/post.dart';
import 'package:talk_it_out/features/feed/feed_providers.dart';

/// Records what the feed asks the server for; serves comments one per page.
class _Recording implements FeedRepository {
  _Recording(this._inner);

  final FeedRepository _inner;
  final postQueries = <({String? topic, String? filter, String? cursor})>[];
  var commentCalls = 0;

  @override
  Future<PageResult<Post>> listPosts({
    int? limit,
    String? cursor,
    String? topic,
    String? filter,
  }) {
    postQueries.add((topic: topic, filter: filter, cursor: cursor));
    return _inner.listPosts(
      limit: 2,
      cursor: cursor,
      topic: topic,
      filter: filter,
    );
  }

  @override
  Future<PageResult<Comment>> listComments(
    String postId, {
    int? limit,
    String? cursor,
  }) {
    commentCalls++;
    return _inner.listComments(postId, limit: 1, cursor: cursor);
  }

  @override
  Future<Post> getPost(String postId) => _inner.getPost(postId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Recording repo;
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(
          MemoryTokenStore()..value = 'mock-token',
        ),
        mockControlsProvider.overrideWithValue(
          MockControls(delay: Duration.zero),
        ),
        feedRepositoryProvider.overrideWith((ref) {
          repo = _Recording(
            MockFeedRepository(
              ref.watch(mockControlsProvider),
              ref.watch(mockBoardProvider),
            ),
          );
          return repo;
        }),
      ],
    );
    addTearDown(container.dispose);
  });

  test('a filter is sent to the server and kept while paging', () async {
    await container.read(feedProvider.future);
    expect(repo.postQueries.last.filter, isNull);

    container
        .read(feedFilterProvider.notifier)
        .set(topic: 'engineering', filter: 'answered');
    final filtered = await container.read(feedProvider.future);
    expect(repo.postQueries.last, (
      topic: 'engineering',
      filter: 'answered',
      cursor: null,
    ));
    for (final post in filtered) {
      expect(post.commentCount, greaterThan(0));
    }

    final notifier = container.read(feedProvider.notifier);
    if (notifier.hasMore) {
      await notifier.loadMore();
      expect(repo.postQueries.last.topic, 'engineering');
      expect(repo.postQueries.last.filter, 'answered');
      expect(repo.postQueries.last.cursor, isNotNull);
    }
  });

  test('setting the same filter again does not refetch', () async {
    await container.read(feedProvider.future);
    final calls = repo.postQueries.length;
    container.read(feedFilterProvider.notifier).set();
    await container.read(feedProvider.future);
    expect(repo.postQueries.length, calls);
  });

  test(
    'mock unanswered filter returns only questions with no comments',
    () async {
      container.read(feedFilterProvider.notifier).set(filter: 'unanswered');
      final posts = await container.read(feedProvider.future);
      expect(posts, isNotEmpty);
      expect(posts.every((p) => p.commentCount == 0), isTrue);
    },
  );

  test('comments load every page, not only the first', () async {
    final feed = container.read(feedRepositoryProvider);
    final postId = MockIds.retroPost;
    final total = (await feed.getPost(postId)).commentCount;
    expect(total, greaterThan(1), reason: 'seed post needs 2+ comments');

    final comments = await container.read(commentsProvider(postId).future);
    expect(comments, hasLength(total));
    expect(comments.map((c) => c.id).toSet(), hasLength(total));
    expect(repo.commentCalls, total);
  });
}
