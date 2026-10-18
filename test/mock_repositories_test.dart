import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/mock/mock_board.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/mock/mock_ids.dart';
import 'package:talk_it_out/core/models/enums.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/features/auth/data/mock_auth_repository.dart';
import 'package:talk_it_out/features/feed/data/mock_feed_repository.dart';
import 'package:talk_it_out/features/groups/data/mock_group_repository.dart';
import 'package:talk_it_out/features/groups/data/mock_message_bridge.dart';
import 'package:talk_it_out/features/notifications/data/mock_notification_repository.dart';
import 'package:talk_it_out/features/review/data/mock_review_repository.dart';
import 'package:talk_it_out/features/review/data/raw_message.dart';

MockControls get _fast => MockControls(delay: Duration.zero);

void main() {
  test('seed covers groups, chat, and my message statuses', () async {
    final board = MockBoard();
    final groups = MockGroupRepository(_fast, board, MockMessageBridge());

    final listed = await groups.listGroups();
    final notes = listed.items.firstWhere(
      (group) => group.id == MockIds.notesGroup,
    );
    final dashboard = listed.items.firstWhere(
      (group) => group.id == MockIds.dashboardGroup,
    );
    expect(notes.myRole, GroupRole.contributor);
    expect(notes.pendingCount, isNull);
    expect(dashboard.myRole, GroupRole.controller);
    expect(dashboard.pendingCount, 6);
    expect(dashboard.sourcePostId, MockIds.dashboardPost);

    final messages = await groups.listMessages(MockIds.notesGroup);
    expect(messages.items.length, greaterThanOrEqualTo(12));
    expect(
      messages.items.any((message) => message.displaySender != null),
      isTrue,
    );
    expect(
      messages.items.any((message) => message.displaySender == null),
      isTrue,
    );

    final page = await groups.listMessages(MockIds.notesGroup, limit: 10);
    expect(page.items, hasLength(10));
    expect(page.nextCursor, '10');

    final mine = await groups.listMyMessages(MockIds.notesGroup);
    expect(
      mine.items.map((message) => message.status),
      containsAll([
        MessageStatus.pending,
        MessageStatus.accepted,
        MessageStatus.rejected,
      ]),
    );

    final before = (await groups.listMessages(MockIds.notesGroup)).items.length;
    final sent = await groups.sendMessage(
      MockIds.notesGroup,
      text: 'A new note',
      isAnonymous: true,
    );
    expect(sent.status, MessageStatus.pending);
    final afterMine = await groups.listMyMessages(MockIds.notesGroup);
    expect(
      afterMine.items.any(
        (message) => message.id == sent.id && message.isAnonymous,
      ),
      isTrue,
    );
    expect(
      (await groups.listMessages(MockIds.notesGroup)).items.length,
      before,
    );

    await expectLater(
      groups.sendMessage(
        MockIds.dashboardGroup,
        text: 'Controllers do not send',
        isAnonymous: false,
      ),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.message,
          'message',
          AppStrings.notAllowed,
        ),
      ),
    );
  });

  test('review queue covers pipeline states and can become empty', () async {
    final review = MockReviewRepository(_fast);
    final queue = await review.listQueue(MockIds.dashboardGroup);
    expect(queue.items, hasLength(6));
    expect(
      queue.items.first.createdAt.isBefore(queue.items.last.createdAt),
      isTrue,
    );

    RawMessage byId(String id) {
      return queue.items.firstWhere((message) => message.id == id);
    }

    final relevant = byId('m201');
    expect(relevant.pipelineStatus, PipelineStatus.done);
    expect(relevant.relevanceLabel, RelevanceLabel.relevant);
    expect(relevant.intentPreservationScore, greaterThan(0.8));
    expect(relevant.isAnonymous, isFalse);

    final offTopic = byId('m202');
    expect(offTopic.relevanceLabel, RelevanceLabel.offTopic);
    expect(offTopic.relevanceScore, lessThan(0.3));

    final anonymous = byId('m203');
    expect(anonymous.isAnonymous, isTrue);
    expect(anonymous.senderId, isNotEmpty);
    expect(anonymous.pipelineStatus, PipelineStatus.done);

    final processing = byId('m204');
    expect(processing.pipelineStatus, PipelineStatus.processing);
    expect(processing.rewrittenText, isNull);
    expect(processing.relevanceScore, isNull);

    expect(byId('m205').pipelineStatus, PipelineStatus.queued);
    expect(byId('m206').rewriteUnavailable, isTrue);

    await expectLater(
      review.listQueue(MockIds.notesGroup),
      throwsA(isA<RepositoryException>()),
    );
    await expectLater(
      review.accept('m206'),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.message,
          'message',
          AppStrings.acceptNoRewrite,
        ),
      ),
    );

    await review.accept('m201');
    await review.accept('m202');
    await review.accept('m203');
    await review.reject('m204');
    await review.reject('m205');
    await review.reject('m206');
    final empty = await review.listQueue(MockIds.dashboardGroup);
    expect(empty.items, isEmpty);
  });

  test('feed seed and group creation follow authorship', () async {
    final board = MockBoard();
    final feed = MockFeedRepository(_fast, board);
    final groups = MockGroupRepository(_fast, board, MockMessageBridge());
    final posts = await feed.listPosts();

    final normal = posts.items.firstWhere(
      (post) => post.id == MockIds.retroPost,
    );
    expect(normal.nsfwFlag, isFalse);
    expect(normal.author.id, MockIds.rohan);
    final flagged = posts.items.firstWhere((post) => post.id == 'p2');
    expect(flagged.nsfwFlag, isTrue);
    final extra = posts.items.firstWhere((post) => post.id == 'p3');
    expect(extra.otherFlags.containsKey('tone_flag'), isTrue);
    expect(posts.items.every((post) => post.author.name.isNotEmpty), isTrue);

    final comments = await feed.listComments(MockIds.retroPost);
    expect(comments.items, hasLength(2));
    expect(comments.items.any((comment) => comment.nsfwFlag), isTrue);

    await expectLater(
      feed.createGroupFromPost(MockIds.retroPost),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.message,
          'message',
          AppStrings.notAllowed,
        ),
      ),
    );
    await expectLater(
      feed.createGroupFromPost(MockIds.dashboardPost),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.message,
          'message',
          AppStrings.groupAlreadyExists,
        ),
      ),
    );

    final removed = await feed.removeReaction(MockIds.retroPost);
    expect(removed.myReaction, isNull);
    expect(removed.reactionCount, 4);

    final created = await feed.createGroupFromPost(MockIds.ownPost);
    expect(created.myRole, GroupRole.controller);
    expect(created.controllerId, MockIds.priya);
    expect(created.sourcePostId, MockIds.ownPost);
    final listed = await groups.listGroups();
    expect(listed.items.any((group) => group.id == created.id), isTrue);
  });

  test('notifications include rejection, review, read, and unknown', () async {
    final notifications = MockNotificationRepository(_fast);
    final items = await notifications.list();
    expect(
      items.items.map((item) => item.type),
      containsAll([
        NotificationType.messageRejected,
        NotificationType.messagePendingReview,
        NotificationType.unknown,
      ]),
    );
    expect(items.items.any((item) => !item.isUnread), isTrue);
    expect(items.items.where((item) => item.isUnread), hasLength(3));
    final unread = await notifications.unreadCount();
    expect(unread.count, 3);

    final read = await notifications.markRead('n1');
    expect(read.isUnread, isFalse);
    expect((await notifications.unreadCount()).count, 2);
  });

  test('auth mock logs in, registers, and can fail on purpose', () async {
    final auth = MockAuthRepository(_fast);
    final session = await auth.login(
      email: 'priya@example.com',
      password: MockAuthRepository.mockPassword,
    );
    expect(session.user.id, MockIds.priya);
    expect(session.user.toJson().containsKey('password'), isFalse);
    expect((await auth.me()).name, 'Priya');
    await auth.logout();

    await expectLater(
      auth.login(email: 'priya@example.com', password: 'nope'),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.message,
          'message',
          AppStrings.wrongLogin,
        ),
      ),
    );

    final created = await auth.register(
      name: 'Neel',
      email: 'neel@example.com',
      password: 'another-pass',
    );
    expect(created.token, isNotEmpty);
    await expectLater(
      auth.register(
        name: 'Priya',
        email: 'priya@example.com',
        password: 'another-pass',
      ),
      throwsA(isA<RepositoryException>()),
    );

    final slow = MockAuthRepository(
      MockControls(delay: const Duration(milliseconds: 30)),
    );
    final watch = Stopwatch()..start();
    await slow.me();
    watch.stop();
    expect(watch.elapsedMilliseconds, greaterThanOrEqualTo(20));

    final failing = MockAuthRepository(
      MockControls(delay: Duration.zero, forceError: true),
    );
    await expectLater(
      failing.me(),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.message,
          'message',
          AppStrings.errorGeneric,
        ),
      ),
    );
  });
}
