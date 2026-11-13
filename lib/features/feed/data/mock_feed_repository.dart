import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/mock/mock_board.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/mock/mock_ids.dart';
import 'package:talk_it_out/core/mock/run_mock.dart';
import 'package:talk_it_out/core/models/enums.dart';
import 'package:talk_it_out/core/models/group.dart';
import 'package:talk_it_out/core/models/group_member.dart';
import 'package:talk_it_out/core/models/page_result.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/features/feed/data/author.dart';
import 'package:talk_it_out/features/feed/data/comment.dart';
import 'package:talk_it_out/features/feed/data/feed_repository.dart';
import 'package:talk_it_out/features/feed/data/post.dart';
import 'package:talk_it_out/features/feed/data/reaction_result.dart';

class MockFeedRepository implements FeedRepository {
  MockFeedRepository(this._controls, this._board) {
    _posts.addAll(_seedPosts());
    _comments.addAll(_seedComments());
  }

  static const _priya = Author(id: MockIds.priya, name: 'Priya');
  static const _rohan = Author(id: MockIds.rohan, name: 'Rohan');
  static const _arhat = Author(id: MockIds.arhat, name: 'Arhat');

  final MockControls _controls;
  final MockBoard _board;
  final List<Post> _posts = [];
  final List<Comment> _comments = [];
  var _nextPost = 20;
  var _nextComment = 20;

  @override
  Future<PageResult<Post>> listPosts({int? limit, String? cursor}) {
    return runMock(_controls, () {
      final posts = List<Post>.of(_posts)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return slicePage(posts, limit: limit, cursor: cursor);
    });
  }

  @override
  Future<Post> createPost({
    required String content,
    String? title,
    String? topic,
  }) {
    return runMock(_controls, () {
      final clean = content.trim();
      if (clean.isEmpty) {
        throw const RepositoryException(
          code: 'validation',
          message: AppStrings.postRequired,
        );
      }
      final post = Post(
        id: 'p$_nextPost',
        author: _priya,
        title: (title == null || title.trim().isEmpty) ? null : title.trim(),
        topic: topic,
        content: clean,
        nsfwFlag: false,
        reactionCount: 0,
        commentCount: 0,
        createdAt: DateTime.now().toUtc(),
      );
      _nextPost += 1;
      _posts.add(post);
      return post;
    });
  }

  @override
  Future<Post> getPost(String postId) {
    return runMock(_controls, () => _requirePost(postId));
  }

  @override
  Future<ReactionResult> addReaction(String postId, {required String type}) {
    return runMock(_controls, () {
      final clean = type.trim();
      if (clean.isEmpty) {
        throw const RepositoryException(
          code: 'validation',
          message: AppStrings.reactionRequired,
        );
      }
      final post = _requirePost(postId);
      final already = post.myReaction != null;
      final updated = post.copyWith(
        myReaction: clean,
        reactionCount: already ? post.reactionCount : post.reactionCount + 1,
      );
      _replacePost(updated);
      return ReactionResult(
        reactionCount: updated.reactionCount,
        myReaction: updated.myReaction,
      );
    });
  }

  @override
  Future<ReactionResult> removeReaction(String postId) {
    return runMock(_controls, () {
      final post = _requirePost(postId);
      final hadReaction = post.myReaction != null;
      final count = hadReaction && post.reactionCount > 0
          ? post.reactionCount - 1
          : post.reactionCount;
      final updated = post.copyWith(myReaction: null, reactionCount: count);
      _replacePost(updated);
      return ReactionResult(reactionCount: count);
    });
  }

  @override
  Future<PageResult<Comment>> listComments(
    String postId, {
    int? limit,
    String? cursor,
  }) {
    return runMock(_controls, () {
      _requirePost(postId);
      final comments = _comments.where((comment) => comment.postId == postId);
      return slicePage(comments.toList(), limit: limit, cursor: cursor);
    });
  }

  @override
  Future<Comment> addComment(String postId, {required String content}) {
    return runMock(_controls, () {
      final clean = content.trim();
      if (clean.isEmpty) {
        throw const RepositoryException(
          code: 'validation',
          message: AppStrings.commentRequired,
        );
      }
      final post = _requirePost(postId);
      final comment = Comment(
        id: 'c$_nextComment',
        postId: postId,
        author: _priya,
        content: clean,
        nsfwFlag: false,
        createdAt: DateTime.now().toUtc(),
      );
      _nextComment += 1;
      _comments.add(comment);
      _replacePost(post.copyWith(commentCount: post.commentCount + 1));
      return comment;
    });
  }

  @override
  Future<Group> createGroupFromPost(String postId) {
    return runMock(_controls, () {
      final post = _requirePost(postId);
      if (post.author.id != MockIds.priya) {
        throw const RepositoryException(
          code: 'forbidden',
          message: AppStrings.notAllowed,
        );
      }
      if (_board.spawnedPostIds.contains(postId)) {
        throw const RepositoryException(
          code: 'conflict',
          message: AppStrings.groupAlreadyExists,
        );
      }
      final id = 'g${_board.nextGroupNumber}';
      _board.nextGroupNumber += 1;
      final group = Group(
        id: id,
        agenda: post.content,
        controllerId: MockIds.priya,
        sourcePostId: postId,
        createdAt: DateTime.now().toUtc(),
        myRole: GroupRole.controller,
        pendingCount: 0,
      );
      _board.spawnedPostIds.add(postId);
      _board.groups.insert(0, group);
      _board.membersByGroup[id] = const [
        GroupMember(
          userId: MockIds.priya,
          name: 'Priya',
          role: GroupRole.controller,
        ),
      ];
      return group;
    });
  }

  Post _requirePost(String postId) {
    for (final post in _posts) {
      if (post.id == postId) return post;
    }
    throw const RepositoryException(
      code: 'not_found',
      message: AppStrings.notFound,
    );
  }

  void _replacePost(Post post) {
    final index = _posts.indexWhere((item) => item.id == post.id);
    _posts[index] = post;
  }

  static List<Post> _seedPosts() {
    return [
      Post(
        id: MockIds.retroPost,
        author: _rohan,
        content: 'Notes from the sprint retro.',
        nsfwFlag: false,
        reactionCount: 5,
        myReaction: 'like',
        commentCount: 2,
        createdAt: DateTime.utc(2026, 10, 4, 9),
      ),
      Post(
        id: MockIds.dashboardPost,
        author: _priya,
        content: 'Dashboard improvements',
        nsfwFlag: false,
        reactionCount: 1,
        commentCount: 0,
        createdAt: DateTime.utc(2026, 10, 5, 9),
      ),
      Post(
        id: 'p3',
        author: _rohan,
        content: 'A note on how we talk about estimates.',
        nsfwFlag: false,
        otherFlags: {'tone_flag': true},
        reactionCount: 0,
        commentCount: 0,
        createdAt: DateTime.utc(2026, 10, 6, 9),
      ),
      Post(
        id: 'p2',
        author: _arhat,
        content: 'Photos from the team offsite.',
        nsfwFlag: true,
        reactionCount: 0,
        commentCount: 0,
        createdAt: DateTime.utc(2026, 10, 7, 9),
      ),
      Post(
        id: MockIds.ownPost,
        author: _priya,
        content: 'I want to make NLP notes',
        nsfwFlag: false,
        reactionCount: 0,
        commentCount: 0,
        createdAt: DateTime.utc(2026, 10, 12, 9),
      ),
    ];
  }

  static List<Comment> _seedComments() {
    return [
      Comment(
        id: 'c1',
        postId: MockIds.retroPost,
        author: _rohan,
        content: 'Count me in',
        nsfwFlag: false,
        createdAt: DateTime.utc(2026, 10, 4, 10),
      ),
      Comment(
        id: 'c2',
        postId: MockIds.retroPost,
        author: _arhat,
        content: 'See the attached image.',
        nsfwFlag: true,
        createdAt: DateTime.utc(2026, 10, 4, 11),
      ),
    ];
  }
}
