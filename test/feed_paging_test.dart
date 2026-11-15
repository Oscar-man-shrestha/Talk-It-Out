import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/api/dio_provider.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/models/page_result.dart';
import 'package:talk_it_out/core/storage/token_store.dart';
import 'package:talk_it_out/features/feed/data/feed_repository.dart';
import 'package:talk_it_out/features/feed/data/mock_feed_repository.dart';
import 'package:talk_it_out/features/feed/data/post.dart';
import 'package:talk_it_out/features/feed/feed_providers.dart';

/// The demo feed, served 4 questions per page like the server's cursor
/// pages.
class _PagedFeed implements FeedRepository {
  _PagedFeed(this._inner);

  final FeedRepository _inner;
  var calls = 0;

  @override
  Future<PageResult<Post>> listPosts({int? limit, String? cursor}) {
    calls++;
    return _inner.listPosts(limit: 4, cursor: cursor);
  }

  // Everything else is not used by this test.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Latest loads every page, once each, without duplicates', () async {
    late _PagedFeed paged;
    final container = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(
          MemoryTokenStore()..value = 'mock-token',
        ),
        mockControlsProvider.overrideWithValue(
          MockControls(delay: Duration.zero),
        ),
        feedRepositoryProvider.overrideWith((ref) {
          paged = _PagedFeed(
            MockFeedRepository(
              ref.watch(mockControlsProvider),
              ref.watch(mockBoardProvider),
            ),
          );
          return paged;
        }),
      ],
    );
    addTearDown(container.dispose);

    final first = await container.read(feedProvider.future);
    expect(first, hasLength(4));
    final notifier = container.read(feedProvider.notifier);
    expect(notifier.hasMore, isTrue);

    // Two calls at once fetch one page.
    await Future.wait([notifier.loadMore(), notifier.loadMore()]);
    expect(container.read(feedProvider).value, hasLength(8));
    expect(paged.calls, 2);

    while (notifier.hasMore) {
      await notifier.loadMore();
    }
    final all = container.read(feedProvider).value!;
    expect(all.map((p) => p.id).toSet(), hasLength(all.length));
    expect(all.length, greaterThan(8));
    await notifier.loadMore(); // nothing left: no extra call
    final calls = paged.calls;
    await notifier.loadMore();
    expect(paged.calls, calls);
  });
}
