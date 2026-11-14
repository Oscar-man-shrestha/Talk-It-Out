import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/mock/mock_board.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/mock/mock_ids.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/models/enums.dart';
import 'package:talk_it_out/features/groups/chat_extras.dart';
import 'package:talk_it_out/features/groups/data/mock_group_repository.dart';
import 'package:talk_it_out/features/groups/data/mock_message_bridge.dart';
import 'package:talk_it_out/features/groups/data/published_message.dart';

void main() {
  final fast = MockControls(delay: Duration.zero);
  MockGroupRepository repo([MockMessageBridge? bridge]) =>
      MockGroupRepository(fast, MockBoard(), bridge ?? MockMessageBridge());

  test('withdraw removes a pending message; a decided one cannot be', () async {
    final bridge = MockMessageBridge();
    final groups = repo(bridge);
    final sent = await groups.sendMessage(
      MockIds.notesGroup,
      text: 'never mind',
      isAnonymous: true,
    );
    await groups.withdrawMessage(sent.id);
    expect(bridge.outgoing.where((m) => m.id == sent.id), isEmpty);
    final mine = await groups.listMyMessages(MockIds.notesGroup);
    expect(mine.items.where((m) => m.id == sent.id), isEmpty);
    expect(
      () => groups.withdrawMessage(sent.id),
      throwsA(isA<RepositoryException>()),
    );
  });

  test('a preview is sent as the same draft', () async {
    final bridge = MockMessageBridge();
    final groups = repo(bridge);
    final id = await groups.requestPreview(
      MockIds.notesGroup,
      text: 'the build is broken',
      isAnonymous: false,
    );
    final preview = await groups.getPreview(MockIds.notesGroup, id);
    expect(preview.ready, isTrue);
    final sent = await groups.sendPreview(
      MockIds.notesGroup,
      id,
      isAnonymous: true,
    );
    expect(sent.status, MessageStatus.pending);
    expect(bridge.outgoing.last.text, 'the build is broken');
    expect(bridge.outgoing.last.isAnonymous, isTrue);
  });

  test('history pages back from the latest; search finds text', () async {
    final groups = repo();
    for (var i = 1; i <= 5; i++) {
      await groups.sendControllerMessage(
        MockIds.dashboardGroup,
        text: 'note $i',
      );
    }
    final all = (await groups.listMessages(MockIds.dashboardGroup)).items;
    final latest = await groups.listMessagesBefore(
      MockIds.dashboardGroup,
      limit: 2,
    );
    expect(latest.items.map((m) => m.text), [
      all[all.length - 2].text,
      all.last.text,
    ]);
    expect(latest.prevCursor, isNotNull);
    final found = await groups.searchMessages(MockIds.dashboardGroup, 'NOTE 3');
    expect(found.map((m) => m.text), ['note 3']);
  });

  test('pins, polls and votes (totals only)', () async {
    final groups = repo();
    final ann = await groups.sendControllerMessage(
      MockIds.dashboardGroup,
      text: 'Retro Friday',
    );
    await groups.setPinned(MockIds.dashboardGroup, ann.id, pinned: true);
    final poll = await groups.createPoll(
      MockIds.dashboardGroup,
      question: 'Which day?',
      options: ['Thu', 'Fri'],
    );
    await groups.vote(MockIds.dashboardGroup, poll.poll!.id, 1);
    await groups.vote(MockIds.dashboardGroup, poll.poll!.id, 0);
    final list = (await groups.listMessages(MockIds.dashboardGroup)).items;
    expect(list.firstWhere((m) => m.id == ann.id).pinned, isTrue);
    final p = list.firstWhere((m) => m.id == poll.id).poll!;
    expect(p.options.map((o) => o.votes), [1, 0]);
    expect(p.myVote, 0);
    expect(p.totalVotes, 1);
    // Contributors cannot pin or post polls.
    expect(
      () => groups.createPoll(
        MockIds.notesGroup,
        question: 'x',
        options: ['a', 'b'],
      ),
      throwsA(isA<RepositoryException>()),
    );
  });

  test('reply_to, pinned and poll are read from the API', () {
    final m = PublishedMessage.fromJson({
      'id': 'p2',
      'group_id': 'g1',
      'text': 'agree',
      'display_sender': null,
      'reply_to': {
        'id': 'p1',
        'text': 'the rota is unfair',
        'display_sender': null,
      },
      'pinned': true,
      'poll': {
        'id': 'po1',
        'options': [
          {'text': 'A', 'votes': 2},
          {'text': 'B', 'votes': 1},
        ],
        'total_votes': 3,
        'my_vote': null,
      },
      'published_at': '2026-11-14T10:00:00.000Z',
    });
    expect(m.replyTo!.id, 'p1');
    expect(m.replyTo!.displaySender, isNull);
    expect(m.pinned, isTrue);
    expect(m.poll!.totalVotes, 3);
    expect(m.poll!.myVote, isNull);
    final plain = PublishedMessage.fromJson({
      'id': 'p3',
      'group_id': 'g1',
      'text': 'hi',
      'published_at': '2026-11-14T10:00:00.000Z',
    });
    expect(plain.replyTo, isNull);
    expect(plain.pinned, isFalse);
    expect(plain.poll, isNull);
  });

  testWidgets('tapping a poll option votes and shows the new totals', (
    tester,
  ) async {
    final groups = repo();
    final msg = await groups.createPoll(
      MockIds.dashboardGroup,
      question: 'Lunch?',
      options: ['Yes', 'No'],
    );
    var poll = msg.poll!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [groupRepositoryProvider.overrideWithValue(groups)],
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) =>
                  PollCard(groupId: MockIds.dashboardGroup, poll: poll),
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('0 votes'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('poll-option-0')));
    await tester.pumpAndSettle();
    poll = (await groups.listMessages(MockIds.dashboardGroup)).items
        .firstWhere((m) => m.id == msg.id)
        .poll!;
    expect(poll.options.first.votes, 1);
    expect(poll.myVote, 0);
  });
}
