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
    // Demo answers get a stable spread of upvotes.
    _comments.addAll([
      for (final (i, c) in _seedComments().indexed)
        c.copyWith(voteCount: c.id.startsWith('qc') ? (i * 7) % 11 : 0),
    ]);
    // Counts always match the comments that exist (no "5 comments" with
    // an empty discussion); you follow your own questions.
    _posts.addAll([
      for (final post in _seedPosts())
        post.copyWith(
          commentCount: _comments.where((c) => c.postId == post.id).length,
          following: post.author.id == MockIds.priya,
        ),
    ]);
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
  final Set<String> _reported = {};

  @override
  Future<PageResult<Post>> listPosts({int? limit, String? cursor}) {
    return runMock(_controls, () {
      final posts = [
        for (final p in _posts)
          if (!_board.blockedUserIds.contains(p.author.id) &&
              !_board.reportedPostIds.contains(p.id))
            p,
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return slicePage(
        posts.map(_namedPost).toList(),
        limit: limit,
        cursor: cursor,
      );
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
        following: true,
      );
      _nextPost += 1;
      _posts.add(post);
      return post;
    });
  }

  @override
  Future<Post> getPost(String postId) {
    return runMock(_controls, () => _namedPost(_requirePost(postId)));
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
      final post = _requirePost(postId);
      final mine = post.author.id == MockIds.priya;
      final comments = _comments
          .where((comment) => comment.postId == postId)
          .map(
            (comment) => comment.copyWith(
              author: _author(comment.author),
              reportedByMe: _reported.contains(comment.id),
              reportCount: mine ? 0 : null,
            ),
          );
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
      // Answering follows the question, as on the server.
      _replacePost(
        post.copyWith(commentCount: post.commentCount + 1, following: true),
      );
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

  @override
  Future<void> deletePost(String postId) {
    return runMock(_controls, () {
      final post = _requirePost(postId);
      if (post.author.id != MockIds.priya) {
        throw const RepositoryException(
          code: 'forbidden',
          message: AppStrings.notAllowed,
        );
      }
      _posts.removeWhere((item) => item.id == postId);
      _comments.removeWhere((item) => item.postId == postId);
    });
  }

  @override
  Future<void> deleteComment(String postId, String commentId) {
    return runMock(_controls, () {
      final post = _requirePost(postId);
      final comment = _requireComment(postId, commentId);
      if (comment.author.id != MockIds.priya &&
          post.author.id != MockIds.priya) {
        throw const RepositoryException(
          code: 'forbidden',
          message: AppStrings.notAllowed,
        );
      }
      _comments.remove(comment);
      _reported.remove(commentId);
      _replacePost(post.copyWith(commentCount: post.commentCount - 1));
    });
  }

  @override
  Future<void> reportComment(
    String postId,
    String commentId, {
    bool report = true,
  }) {
    return runMock(_controls, () {
      final comment = _requireComment(postId, commentId);
      if (comment.author.id == MockIds.priya) {
        throw const RepositoryException(
          code: 'own_comment',
          message: AppStrings.cannotReportOwn,
        );
      }
      if (report) {
        _reported.add(commentId);
      } else {
        _reported.remove(commentId);
      }
    });
  }

  Comment _requireComment(String postId, String commentId) {
    for (final comment in _comments) {
      if (comment.id == commentId && comment.postId == postId) return comment;
    }
    throw const RepositoryException(
      code: 'not_found',
      message: AppStrings.notFound,
    );
  }

  /// Your own questions and answers carry your current demo name.
  Author _author(Author a) =>
      Author(id: a.id, name: _board.nameOf(a.id, a.name));

  Post _namedPost(Post p) => p.copyWith(author: _author(p.author));

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
      Post(
        id: 'q1',
        author: const Author(id: 'u4', name: 'Anita Gurung'),
        title: 'How do you make the case for paying down tech debt?',
        topic: 'engineering',
        content: 'Our deploys break every other week because of an old billing module. Product keeps prioritising features. What data convinced your leadership to give time for refactoring?',
        nsfwFlag: false,
        reactionCount: 7,
        commentCount: 3,
        createdAt: DateTime.utc(2026, 10, 8, 9),
      ),
      Post(
        id: 'q2',
        author: const Author(id: 'u6', name: 'Katherine Rai'),
        title: 'My manager presents my work as their own',
        topic: 'leadership',
        content: 'In the last two leadership updates, my manager showed the analysis I built without mentioning me. I want credit without starting a fight. How would you raise this?',
        nsfwFlag: false,
        reactionCount: 12,
        commentCount: 5,
        createdAt: DateTime.utc(2026, 10, 9, 10),
      ),
      Post(
        id: 'q3',
        author: const Author(id: 'u7', name: 'Sujan Karki'),
        title: 'Is my salary fair for my level?',
        topic: 'compensation',
        content: 'I found out a new hire at the same level earns noticeably more than me. I have been here three years with good reviews. How should I bring this up with HR?',
        nsfwFlag: false,
        reactionCount: 4,
        commentCount: 1,
        createdAt: DateTime.utc(2026, 10, 10, 11),
      ),
      Post(
        id: 'q4',
        author: const Author(id: 'u5', name: 'Bikash Thapa'),
        title: 'People stay quiet in retros. How do we fix it?',
        topic: 'safety',
        content: 'Our retrospectives are polite and useless. Everyone says things went fine, then complains in private. What helped your team speak honestly?',
        nsfwFlag: false,
        reactionCount: 9,
        commentCount: 4,
        createdAt: DateTime.utc(2026, 10, 11, 12),
      ),
      Post(
        id: 'q5',
        author: const Author(id: 'u8', name: 'Maya Tamang'),
        title: 'How do I ask for a promotion to senior engineer?',
        content: 'I have been doing senior-level work for a year: leading a project, mentoring two juniors. My manager has not mentioned promotion. How do I start this conversation?',
        nsfwFlag: false,
        reactionCount: 15,
        commentCount: 6,
        createdAt: DateTime.utc(2026, 10, 12, 13),
      ),
      Post(
        id: 'q6',
        author: const Author(id: 'u10', name: 'Alex Dev'),
        title: 'Burned out but the project is not done',
        content: 'I have worked most weekends for two months. I am exhausted and making mistakes. How do I say I need a break without letting the team down?',
        nsfwFlag: false,
        reactionCount: 6,
        commentCount: 2,
        createdAt: DateTime.utc(2026, 10, 13, 14),
      ),
      Post(
        id: 'q7',
        author: const Author(id: 'u11', name: 'Sophia Lee'),
        title: 'Meetings across time zones are killing us',
        content: 'Half the team is eight hours ahead. Someone always joins at night. How do you run a distributed team without making one side suffer?',
        nsfwFlag: false,
        reactionCount: 3,
        commentCount: 0,
        createdAt: DateTime.utc(2026, 10, 14, 15),
      ),
      Post(
        id: 'q8',
        author: const Author(id: 'u3', name: 'Rohan Basnet'),
        title: 'How do I give hard feedback to a peer?',
        content: 'A peer\'s work often arrives late and incomplete, which blocks me. We are on the same level. How do I raise it kindly but clearly?',
        nsfwFlag: false,
        reactionCount: 8,
        commentCount: 3,
        createdAt: DateTime.utc(2026, 10, 15, 16),
      ),
      Post(
        id: 'q9',
        author: const Author(id: 'u4', name: 'Anita Gurung'),
        title: 'How do I explain a layoff in interviews?',
        content: 'I was laid off with a third of the company. Interviewers keep asking why I left. What is a good honest answer?',
        nsfwFlag: false,
        reactionCount: 5,
        commentCount: 2,
        createdAt: DateTime.utc(2026, 10, 16, 9),
      ),
      Post(
        id: 'q10',
        author: const Author(id: 'u7', name: 'Sujan Karki'),
        title: 'Leaving a big company for an early-stage startup',
        content: 'I have an offer from a seed-stage startup: lower salary, some equity. How did you judge whether the startup was a good bet?',
        nsfwFlag: false,
        reactionCount: 11,
        commentCount: 4,
        createdAt: DateTime.utc(2026, 10, 17, 10),
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
      Comment(
        id: 'qc1',
        postId: 'q1',
        author: const Author(id: 'u5', name: 'Bikash Thapa'),
        content: 'Track how many hours each incident in the billing module costs. A number like \'40 engineer hours a month\' got us a refactoring sprint.',
        nsfwFlag: false,
        createdAt: DateTime.utc(2026, 10, 8, 11),
      ),
      Comment(
        id: 'qc2',
        postId: 'q1',
        author: const Author(id: 'u8', name: 'Maya Tamang'),
        content: 'Tie it to something product cares about: our checkout bugs dropped after we fixed the old payment code, and that convinced them.',
        nsfwFlag: false,
        createdAt: DateTime.utc(2026, 10, 8, 12),
      ),
      Comment(
        id: 'qc3',
        postId: 'q1',
        author: const Author(id: 'u2', name: 'Rohan'),
        content: 'Ask for 20% of each sprint instead of one big rewrite. Small, steady payments are easier to approve.',
        nsfwFlag: false,
        createdAt: DateTime.utc(2026, 10, 8, 13),
      ),
      Comment(
        id: 'qc4',
        postId: 'q2',
        author: const Author(id: 'u4', name: 'Anita Gurung'),
        content: 'Before the next update, send your manager a short note: \'Happy to present the analysis slide myself if useful.\' It makes credit the easy option.',
        nsfwFlag: false,
        createdAt: DateTime.utc(2026, 10, 9, 11),
      ),
      Comment(
        id: 'qc5',
        postId: 'q2',
        author: const Author(id: 'u8', name: 'Maya Tamang'),
        content: 'Put your name in the file itself: a footer like \'Analysis: Katherine Rai\' travels with the slides.',
        nsfwFlag: false,
        createdAt: DateTime.utc(2026, 10, 9, 12),
      ),
      Comment(
        id: 'qc6',
        postId: 'q2',
        author: const Author(id: 'u7', name: 'Sujan Karki'),
        content: 'In your one-to-one, ask how the leadership update went and whether the analysis answered their questions. It opens the door calmly.',
        nsfwFlag: false,
        createdAt: DateTime.utc(2026, 10, 9, 13),
      ),
      Comment(
        id: 'qc7',
        postId: 'q2',
        author: const Author(id: 'u10', name: 'Alex Dev'),
        content: 'If it keeps happening, keep a short record of what you built and when. It helps at review time, even if you never need it.',
        nsfwFlag: false,
        createdAt: DateTime.utc(2026, 10, 9, 14),
      ),
      Comment(
        id: 'qc8',
        postId: 'q2',
        author: const Author(id: 'u1', name: 'Priya'),
        content: 'Sometimes managers simply forget. Assume good intent first, but be specific about what you\'d like next time.',
        nsfwFlag: false,
        createdAt: DateTime.utc(2026, 10, 9, 15),
      ),
      Comment(
        id: 'qc9',
        postId: 'q3',
        author: const Author(id: 'u5', name: 'Bikash Thapa'),
        content: 'Check a few salary surveys for your role and city first, then ask HR how pay bands work at your level. Facts make the conversation easier.',
        nsfwFlag: false,
        createdAt: DateTime.utc(2026, 10, 10, 11),
      ),
      Comment(
        id: 'qc10',
        postId: 'q4',
        author: const Author(id: 'u6', name: 'Katherine Rai'),
        content: 'We added an anonymous round at the start of each retro. People wrote what they would not say aloud, and the discussion changed completely.',
        nsfwFlag: false,
        createdAt: DateTime.utc(2026, 10, 11, 11),
      ),
      Comment(
        id: 'qc11',
        postId: 'q4',
        author: const Author(id: 'u4', name: 'Anita Gurung'),
        content: 'Rotate who runs the retro. When the manager isn\'t the facilitator, people relax.',
        nsfwFlag: false,
        createdAt: DateTime.utc(2026, 10, 11, 12),
      ),
      Comment(
        id: 'qc12',
        postId: 'q4',
        author: const Author(id: 'u2', name: 'Rohan'),
        content: 'Start with one concrete question, like \'What slowed you down most this sprint?\', instead of \'Any feedback?\'',
        nsfwFlag: false,
        createdAt: DateTime.utc(2026, 10, 11, 13),
      ),
      Comment(
        id: 'qc13',
        postId: 'q4',
        author: const Author(id: 'u1', name: 'Priya'),
        content: 'Follow up on one item from the last retro every time. People speak up when they see it leads to change.',
        nsfwFlag: false,
        createdAt: DateTime.utc(2026, 10, 11, 14),
      ),
      Comment(
        id: 'qc14',
        postId: 'q5',
        author: const Author(id: 'u4', name: 'Anita Gurung'),
        content: 'Ask your manager directly: \'What would I need to show to be promoted to senior in the next six months?\' Then write the answer down.',
        nsfwFlag: false,
        createdAt: DateTime.utc(2026, 10, 12, 11),
      ),
      Comment(
        id: 'qc15',
        postId: 'q5',
        author: const Author(id: 'u6', name: 'Katherine Rai'),
        content: 'Collect evidence as you go: the project you led, the people you mentored, the decisions you made.',
        nsfwFlag: false,
        createdAt: DateTime.utc(2026, 10, 12, 12),
      ),
      Comment(
        id: 'qc16',
        postId: 'q5',
        author: const Author(id: 'u7', name: 'Sujan Karki'),
        content: 'Find out who else has a say. Often a promotion committee decides, not only your manager.',
        nsfwFlag: false,
        createdAt: DateTime.utc(2026, 10, 12, 13),
      ),
      Comment(
        id: 'qc17',
        postId: 'q5',
        author: const Author(id: 'u5', name: 'Bikash Thapa'),
        content: 'Ask to own something visible next quarter, like a design review or an on-call improvement.',
        nsfwFlag: false,
        createdAt: DateTime.utc(2026, 10, 12, 14),
      ),
      Comment(
        id: 'qc18',
        postId: 'q5',
        author: const Author(id: 'u10', name: 'Alex Dev'),
        content: 'Peers\' written feedback helped my case a lot. Ask two or three people you\'ve helped.',
        nsfwFlag: false,
        createdAt: DateTime.utc(2026, 10, 12, 15),
      ),
      Comment(
        id: 'qc19',
        postId: 'q5',
        author: const Author(id: 'u2', name: 'Rohan'),
        content: 'Be patient but clear. If the answer is \'not yet\', ask what exactly is missing.',
        nsfwFlag: false,
        createdAt: DateTime.utc(2026, 10, 12, 16),
      ),
      Comment(
        id: 'qc20',
        postId: 'q6',
        author: const Author(id: 'u8', name: 'Maya Tamang'),
        content: 'Tell your manager what you can realistically do this week, not just that you\'re tired. A concrete plan is easier to say yes to.',
        nsfwFlag: false,
        createdAt: DateTime.utc(2026, 10, 13, 11),
      ),
      Comment(
        id: 'qc21',
        postId: 'q6',
        author: const Author(id: 'u1', name: 'Priya'),
        content: 'Take the weekend fully off. A team that depends on one person\'s weekends has a planning problem, not a you problem.',
        nsfwFlag: false,
        createdAt: DateTime.utc(2026, 10, 13, 12),
      ),
      Comment(
        id: 'qc22',
        postId: 'q8',
        author: const Author(id: 'u11', name: 'Sophia Lee'),
        content: 'Say it calmly in the moment: \'I\'d like to finish my point, then I\'m keen to hear yours.\' It works more often than you\'d think.',
        nsfwFlag: false,
        createdAt: DateTime.utc(2026, 10, 15, 11),
      ),
      Comment(
        id: 'qc23',
        postId: 'q8',
        author: const Author(id: 'u6', name: 'Katherine Rai'),
        content: 'Ask the facilitator to go round the room for design reviews. Structure stops interruptions.',
        nsfwFlag: false,
        createdAt: DateTime.utc(2026, 10, 15, 12),
      ),
      Comment(
        id: 'qc24',
        postId: 'q8',
        author: const Author(id: 'u4', name: 'Anita Gurung'),
        content: 'Have a quiet word afterwards. Most people don\'t notice they do it.',
        nsfwFlag: false,
        createdAt: DateTime.utc(2026, 10, 15, 13),
      ),
      Comment(
        id: 'qc25',
        postId: 'q9',
        author: const Author(id: 'u10', name: 'Alex Dev'),
        content: 'Only if you\'d genuinely stay for a counter-offer. Once you say it, the relationship changes either way.',
        nsfwFlag: false,
        createdAt: DateTime.utc(2026, 10, 16, 11),
      ),
      Comment(
        id: 'qc26',
        postId: 'q9',
        author: const Author(id: 'u8', name: 'Maya Tamang'),
        content: 'I told my manager and got a raise, but I was still the first person they thought of when plans changed. Be careful.',
        nsfwFlag: false,
        createdAt: DateTime.utc(2026, 10, 16, 12),
      ),
      Comment(
        id: 'qc27',
        postId: 'q10',
        author: const Author(id: 'u2', name: 'Rohan'),
        content: 'Ask how many months of money they have left and when they plan to raise again.',
        nsfwFlag: false,
        createdAt: DateTime.utc(2026, 10, 17, 11),
      ),
      Comment(
        id: 'qc28',
        postId: 'q10',
        author: const Author(id: 'u6', name: 'Katherine Rai'),
        content: 'Talk to an early employee who left. They will tell you what the founders won\'t.',
        nsfwFlag: false,
        createdAt: DateTime.utc(2026, 10, 17, 12),
      ),
      Comment(
        id: 'qc29',
        postId: 'q10',
        author: const Author(id: 'u4', name: 'Anita Gurung'),
        content: 'Equity at seed stage is a lottery ticket. Take the job only if the salary works for you on its own.',
        nsfwFlag: false,
        createdAt: DateTime.utc(2026, 10, 17, 13),
      ),
      Comment(
        id: 'qc30',
        postId: 'q10',
        author: const Author(id: 'u5', name: 'Bikash Thapa'),
        content: 'The learning is the real pay. I grew more in one year at a startup than in three at a big company.',
        nsfwFlag: false,
        createdAt: DateTime.utc(2026, 10, 17, 14),
      ),
    ];
  }

  @override
  Future<bool> setFollowing(String postId, {required bool following}) {
    return runMock(_controls, () {
      final post = _requirePost(postId);
      _replacePost(post.copyWith(following: following));
      return following;
    });
  }

  @override
  Future<CommentVote> voteComment(
    String postId,
    String commentId, {
    required bool up,
  }) {
    return runMock(_controls, () {
      final comment = _requireComment(postId, commentId);
      if (up && comment.author.id == MockIds.priya) {
        throw const RepositoryException(
          code: 'validation',
          message: 'You cannot upvote your own answer.',
        );
      }
      if (comment.votedByMe == up) {
        return CommentVote(count: comment.voteCount, votedByMe: up);
      }
      final next = comment.copyWith(
        votedByMe: up,
        voteCount: comment.voteCount + (up ? 1 : -1),
      );
      _comments[_comments.indexOf(comment)] = next;
      return CommentVote(count: next.voteCount, votedByMe: up);
    });
  }

  @override
  Future<void> setBestAnswer(String postId, String? commentId) {
    return runMock(_controls, () {
      final post = _requirePost(postId);
      if (post.author.id != MockIds.priya) {
        throw const RepositoryException(
          code: 'forbidden',
          message: 'Only the person who asked can choose the best answer.',
        );
      }
      if (commentId != null) _requireComment(postId, commentId);
      _replacePost(post.copyWith(bestCommentId: commentId));
      for (var i = 0; i < _comments.length; i++) {
        final c = _comments[i];
        if (c.postId == postId) {
          _comments[i] = c.copyWith(isBest: c.id == commentId);
        }
      }
    });
  }

  @override
  Future<Post> editPost(
    String postId, {
    String? title,
    String? topic,
    String? content,
  }) {
    return runMock(_controls, () {
      final post = _requirePost(postId);
      if (post.author.id != MockIds.priya) {
        throw const RepositoryException(
          code: 'forbidden',
          message: 'You can only edit your own question.',
        );
      }
      final next = post.copyWith(
        title: title ?? post.title,
        topic: topic ?? post.topic,
        content: content?.trim() ?? post.content,
        editedAt: DateTime.now().toUtc(),
      );
      _replacePost(next);
      return next;
    });
  }

  @override
  Future<Comment> editComment(
    String postId,
    String commentId, {
    required String content,
  }) {
    return runMock(_controls, () {
      final comment = _requireComment(postId, commentId);
      if (comment.author.id != MockIds.priya) {
        throw const RepositoryException(
          code: 'forbidden',
          message: 'You can only edit your own answer.',
        );
      }
      final clean = content.trim();
      if (clean.isEmpty) {
        throw const RepositoryException(
          code: 'validation',
          message: AppStrings.commentRequired,
        );
      }
      final next = comment.copyWith(
        content: clean,
        editedAt: DateTime.now().toUtc(),
      );
      _comments[_comments.indexOf(comment)] = next;
      return next;
    });
  }
}
