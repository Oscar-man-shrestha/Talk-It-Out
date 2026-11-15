import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/realtime/realtime_client.dart';
import 'package:talk_it_out/features/feed/data/comment.dart';
import 'package:talk_it_out/features/feed/data/post.dart';

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
    final page = await ref.watch(feedRepositoryProvider).listPosts();
    _cursor = page.nextCursor;
    return page.items;
  }

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
          .listPosts(cursor: cursor);
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
    final page = await ref.watch(feedRepositoryProvider).listComments(postId);
    return page.items;
  }
}

final commentsProvider =
    AsyncNotifierProvider.family<CommentsNotifier, List<Comment>, String>(
      CommentsNotifier.new,
    );
