import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/mock/mock_board.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/mock/mock_ids.dart';
import 'package:talk_it_out/core/models/enums.dart';
import 'package:talk_it_out/features/feed/data/comment.dart';
import 'package:talk_it_out/features/feed/data/mock_feed_repository.dart';
import 'package:talk_it_out/features/review/data/mock_review_repository.dart';
import 'package:talk_it_out/features/review/data/raw_message.dart';

void main() {
  final fast = MockControls(delay: Duration.zero);

  group('review history', () {
    test('decided messages move to the Approved / Rejected tabs', () async {
      final repo = MockReviewRepository(fast);
      final before = await repo.counts(MockIds.dashboardGroup);
      await repo.reject('m201');
      final after = await repo.counts(MockIds.dashboardGroup);
      expect(after.rejected, before.rejected + 1);
      expect(after.pending, before.pending - 1);

      final rejected = await repo.listQueue(
        MockIds.dashboardGroup,
        status: MessageStatus.rejected,
      );
      expect(rejected.items.map((m) => m.id), contains('m201'));
      expect(rejected.items.first.decidedAt, isNotNull);
      final pending = await repo.listQueue(MockIds.dashboardGroup);
      expect(pending.items.map((m) => m.id), isNot(contains('m201')));
    });

    test('decided_at is read from the API and is optional', () {
      Map<String, dynamic> json(String? decided) => {
        'id': 'm1',
        'group_id': 'g1',
        'sender_id': 'u1',
        'sender_name': 'A',
        'original_text': 'x',
        'rewritten_text': 'y',
        'is_anonymous': false,
        'intent_preservation_score': 1,
        'relevance_score': 1,
        'relevance_label': 'relevant',
        'pipeline_status': 'done',
        'status': 'accepted',
        'created_at': '2026-11-14T10:00:00.000Z',
        'decided_at': decided,
      };
      expect(
        RawMessage.fromJson(json('2026-11-14T11:00:00.000Z')).decidedAt,
        DateTime.utc(2026, 11, 14, 11),
      );
      expect(RawMessage.fromJson(json(null)).decidedAt, isNull);
    });
  });

  group('comments', () {
    test('report, withdraw, and no reporting your own comment', () async {
      final feed = MockFeedRepository(fast, MockBoard());
      await feed.reportComment(MockIds.retroPost, 'c1');
      var comments = await feed.listComments(MockIds.retroPost);
      expect(comments.items.firstWhere((c) => c.id == 'c1').reportedByMe, true);
      await feed.reportComment(MockIds.retroPost, 'c1', report: false);
      comments = await feed.listComments(MockIds.retroPost);
      expect(
        comments.items.firstWhere((c) => c.id == 'c1').reportedByMe,
        false,
      );

      final mine = await feed.addComment(MockIds.retroPost, content: 'Mine');
      expect(
        () => feed.reportComment(MockIds.retroPost, mine.id),
        throwsA(isA<RepositoryException>()),
      );
    });

    test('you can remove your own comment but not someone else\'s '
        'on a question you did not ask', () async {
      final feed = MockFeedRepository(fast, MockBoard());
      final mine = await feed.addComment(MockIds.retroPost, content: 'Mine');
      await feed.deleteComment(MockIds.retroPost, mine.id);
      final ids = (await feed.listComments(MockIds.retroPost)).items
          .map((c) => c.id);
      expect(ids, isNot(contains(mine.id)));
      expect(
        () => feed.deleteComment(MockIds.retroPost, 'c1'),
        throwsA(isA<RepositoryException>()),
      );
    });

    test('report fields are read from the API with safe defaults', () {
      final base = {
        'id': 'c1',
        'post_id': 'p1',
        'author': {'id': 'u1', 'name': 'A'},
        'content': 'hi',
        'nsfw_flag': false,
        'other_flags': <String, dynamic>{},
        'created_at': '2026-11-14T10:00:00.000Z',
      };
      final plain = Comment.fromJson(base);
      expect(plain.reportCount, isNull);
      expect(plain.reportedByMe, false);
      final full = Comment.fromJson({
        ...base,
        'report_count': 2,
        'reported_by_me': true,
      });
      expect(full.reportCount, 2);
      expect(full.reportedByMe, true);
    });
  });

  test('only the author can delete a question', () async {
    final feed = MockFeedRepository(fast, MockBoard());
    expect(
      () => feed.deletePost(MockIds.retroPost),
      throwsA(isA<RepositoryException>()),
    );
    final own = await feed.createPost(content: 'A question of mine');
    await feed.deletePost(own.id);
    expect(() => feed.getPost(own.id), throwsA(isA<RepositoryException>()));
  });
}
