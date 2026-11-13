import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/realtime/realtime_client.dart';
import 'package:talk_it_out/features/feed/data/comment.dart';
import 'package:talk_it_out/features/feed/data/post.dart';

class FeedNotifier extends AsyncNotifier<List<Post>> {
  @override
  Future<List<Post>> build() async {
    refreshOnLiveEvents(
      ref,
      (e) => e.type == 'feed',
      refresh: ref.invalidateSelf,
    );
    final page = await ref.watch(feedRepositoryProvider).listPosts();
    return page.items;
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
