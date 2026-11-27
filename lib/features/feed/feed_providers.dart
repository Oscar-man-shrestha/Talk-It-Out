import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/realtime/realtime_client.dart';
import 'package:talk_it_out/features/feed/data/comment.dart';
import 'package:talk_it_out/features/feed/data/post.dart';

/// The Latest tab's server-side filters (`API.md` 70). Null means all.
typedef FeedFilter = ({String? topic, String? filter});

class FeedFilterNotifier extends Notifier<FeedFilter> {
  @override
  FeedFilter build() => (topic: null, filter: null);

  void set({String? topic, String? filter}) {
    final next = (topic: topic, filter: filter);
    if (next != state) state = next;
  }
}

final feedFilterProvider = NotifierProvider<FeedFilterNotifier, FeedFilter>(
  FeedFilterNotifier.new,
);

class FeedNotifier extends AsyncNotifier<List<Post>> {
  String? _cursor;
  var _loadingMore = false;

  /// True while older questions are still on the server.
  bool get hasMore => _cursor != null;

  bool get loadingMore => _loadingMore;

  @override
  Future<List<Post>> build() async {
    refreshOnLiveEvents(
      ref,
      (e) => e.type == 'feed',
      refresh: ref.invalidateSelf,
    );
    final filter = ref.watch(feedFilterProvider);
    _filter = filter;
    // Reset first: a page still loading for the old filter must not be
    // appended to this one.
    _cursor = null;
    final page = await ref
        .watch(feedRepositoryProvider)
        .listPosts(topic: filter.topic, filter: filter.filter);
    _cursor = page.nextCursor;
    return page.items;
  }

  FeedFilter _filter = (topic: null, filter: null);

  /// Appends the next page (endless scrolling). Safe to call repeatedly:
  /// it does nothing while a page is loading or when there is no more.
  Future<void> loadMore() async {
    final current = state.value;
    final cursor = _cursor;
    if (current == null || cursor == null || _loadingMore) return;
    _loadingMore = true;
    try {
      final page = await ref
          .read(feedRepositoryProvider)
          .listPosts(
            cursor: cursor,
            topic: _filter.topic,
            filter: _filter.filter,
          );
      // A refresh started meanwhile: keep its fresh first page instead.
      if (_cursor != cursor) return;
      final seen = {for (final p in current) p.id};
      _cursor = page.nextCursor;
      state = AsyncData([
        ...current,
        ...page.items.where((p) => !seen.contains(p.id)),
      ]);
    } finally {
      _loadingMore = false;
    }
  }
}

final feedProvider = AsyncNotifierProvider<FeedNotifier, List<Post>>(
  FeedNotifier.new,
);

class PostDetailNotifier extends AsyncNotifier<Post> {
  PostDetailNotifier(this.postId);

  final String postId;

  @override
  Future<Post> build() {
    refreshOnLiveEvents(
      ref,
      (e) => e.type == 'feed' && e.postId == postId,
      refresh: ref.invalidateSelf,
    );
    return ref.watch(feedRepositoryProvider).getPost(postId);
  }
}

final postDetailProvider =
    AsyncNotifierProvider.family<PostDetailNotifier, Post, String>(
      PostDetailNotifier.new,
    );

class CommentsNotifier extends AsyncNotifier<List<Comment>> {
  CommentsNotifier(this.postId);

  final String postId;

  @override
  Future<List<Comment>> build() async {
    refreshOnLiveEvents(
      ref,
      (e) => e.type == 'feed' && e.postId == postId,
      refresh: ref.invalidateSelf,
    );
    // Every page: a busy question must not silently stop at the first
    // page of answers. Capped so a runaway cursor cannot loop forever.
    final repo = ref.watch(feedRepositoryProvider);
    final items = <Comment>[];
    final seen = <String>{};
    String? cursor;
    for (var page = 0; page < _maxCommentPages; page++) {
      final result = await repo.listComments(postId, cursor: cursor);
      for (final comment in result.items) {
        if (seen.add(comment.id)) items.add(comment);
      }
      cursor = result.nextCursor;
      if (cursor == null) break;
    }
    return items;
  }
}

/// 20 pages of 50: far more answers than any question is expected to get.
const _maxCommentPages = 20;

final commentsProvider =
    AsyncNotifierProvider.family<CommentsNotifier, List<Comment>, String>(
      CommentsNotifier.new,
    );
