import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/api/dio_provider.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/mock/mock_ids.dart';
import 'package:talk_it_out/core/models/enums.dart';
import 'package:talk_it_out/core/models/group_member.dart';
import 'package:talk_it_out/core/storage/token_store.dart';
import 'package:talk_it_out/features/groups/composer_helpers.dart';
import 'package:talk_it_out/features/groups/group_chat_screen.dart';
import 'package:talk_it_out/features/groups/group_info_screen.dart';
import 'package:talk_it_out/features/groups/group_providers.dart';
import 'package:talk_it_out/features/notifications/data/app_notification.dart';
import 'package:talk_it_out/features/notifications/notification_text.dart';

ProviderContainer _container() {
  final c = ProviderContainer(
    overrides: [
      tokenStoreProvider.overrideWithValue(
        MemoryTokenStore()..value = 'mock-token',
      ),
      mockControlsProvider.overrideWithValue(
        MockControls(delay: Duration.zero),
      ),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('answers', () {
    test('upvote and take it back; never your own', () async {
      final feed = _container().read(feedRepositoryProvider);
      final answers = (await feed.listComments('q2')).items;
      final first = answers.first;
      final up = await feed.voteComment('q2', first.id, up: true);
      expect(up.votedByMe, isTrue);
      expect(up.count, first.voteCount + 1);
      final down = await feed.voteComment('q2', first.id, up: false);
      expect(down.count, first.voteCount);

      final mine = await feed.addComment(MockIds.ownPost, content: 'My own');
      expect(
        () => feed.voteComment(MockIds.ownPost, mine.id, up: true),
        throwsA(isA<RepositoryException>()),
      );
    });

    test('the asker marks a best answer; others cannot', () async {
      final feed = _container().read(feedRepositoryProvider);
      final answer = await feed.addComment(MockIds.ownPost, content: 'Idea');
      await feed.setBestAnswer(MockIds.ownPost, answer.id);
      final list = (await feed.listComments(MockIds.ownPost)).items;
      expect(list.singleWhere((c) => c.id == answer.id).isBest, isTrue);
      expect((await feed.getPost(MockIds.ownPost)).bestCommentId, answer.id);
      await feed.setBestAnswer(MockIds.ownPost, null);
      expect((await feed.getPost(MockIds.ownPost)).bestCommentId, isNull);
      final other = (await feed.listComments('q2')).items.first;
      expect(
        () => feed.setBestAnswer('q2', other.id),
        throwsA(isA<RepositoryException>()),
      );
    });

    test('follow, edit, and answering follows', () async {
      final feed = _container().read(feedRepositoryProvider);
      expect((await feed.getPost('q4')).following, isFalse);
      expect(await feed.setFollowing('q4', following: true), isTrue);
      expect((await feed.getPost('q4')).following, isTrue);
      expect((await feed.getPost(MockIds.ownPost)).following, isTrue);

      final edited = await feed.editPost(
        MockIds.ownPost,
        title: 'Better title',
      );
      expect(edited.title, 'Better title');
      expect(edited.editedAt, isNotNull);
      expect(
        () => feed.editPost('q2', title: 'Not mine'),
        throwsA(isA<RepositoryException>()),
      );

      await feed.addComment('q5', content: 'Answering');
      expect((await feed.getPost('q5')).following, isTrue);
    });
  });

  test('feed notifications have a question, not a group', () {
    final n = AppNotification.fromJson({
      'id': 'n1',
      'type': 'question_answered',
      'ref_id': 'c1',
      'group': null,
      'post': {'id': 'p1', 'title': 'How do I ask for a raise?'},
      'created_at': '2026-11-16T10:00:00Z',
      'read_at': null,
    });
    expect(n.type, NotificationType.questionAnswered);
    expect(n.group, isNull);
    expect(notificationText(n), 'New answer on "How do I ask for a raise?".');
    final mention = AppNotification.fromJson({
      'id': 'n2',
      'type': 'mentioned',
      'ref_id': 'm1',
      'group': {'id': 'g1', 'agenda': 'Retro'},
      'created_at': '2026-11-16T10:00:00Z',
    });
    // Never names the sender: the message may be anonymous.
    expect(notificationText(mention), 'You were mentioned in Retro.');
  });

  group('groups', () {
    test(
      'muted groups stay out of the badge; settings are per group',
      () async {
        final c = _container();
        final repo = c.read(groupRepositoryProvider);
        await repo.updateGroupSettings(
          MockIds.notesGroup,
          muted: true,
          pinned: true,
        );
        final g = await repo.getGroup(MockIds.notesGroup);
        expect(g.muted, isTrue);
        expect(g.pinned, isTrue);
        expect((await repo.getGroup(MockIds.dashboardGroup)).muted, isFalse);
        await c.read(groupsProvider.future);
        await c.read(groupMessagesProvider(MockIds.notesGroup).future);
        await c.read(groupMessagesProvider(MockIds.dashboardGroup).future);
        expect(
          c.read(groupsUnreadTotalProvider),
          c.read(groupUnreadCountProvider(MockIds.dashboardGroup)),
        );
      },
    );

    test('only the controller edits the description and rules', () async {
      final repo = _container().read(groupRepositoryProvider);
      await repo.updateGroupInfo(MockIds.dashboardGroup, rules: 'Be kind.');
      expect((await repo.getGroup(MockIds.dashboardGroup)).rules, 'Be kind.');
      expect(
        () => repo.updateGroupInfo(MockIds.notesGroup, rules: 'Nope'),
        throwsA(isA<RepositoryException>()),
      );
    });

    testWidgets('group info shows rules and switches mute', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = _container();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(
            home: GroupInfoScreen(groupId: MockIds.dashboardGroup),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dashboard improvements'), findsOneWidget);
      expect(
        find.textContaining('Talk about problems, not people'),
        findsOneWidget,
      );
      // The controller can edit.
      expect(find.text('Edit'), findsWidgets);
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('info-mute')),
          matching: find.byType(Switch),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        (await c.read(groupRepositoryProvider).getGroup(MockIds.dashboardGroup))
            .muted,
        isTrue,
      );
    });
  });

  group('chat helpers', () {
    const members = [
      GroupMember(userId: 'u1', name: 'Priya', role: GroupRole.controller),
      GroupMember(
        userId: 'u4',
        name: 'Anita Gurung',
        role: GroupRole.contributor,
      ),
      GroupMember(
        userId: 'u5',
        name: 'Bikash Thapa',
        role: GroupRole.contributor,
      ),
    ];

    test('finds the mention being typed', () {
      TextEditingValue v(String text) => TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      expect(activeMention(v('Thanks @an')), (start: 7, query: 'an'));
      expect(activeMention(v('@')), (start: 0, query: ''));
      expect(activeMention(v('mail me at me@x.com')), isNull);
      expect(activeMention(v('no mention')), isNull);
      expect(mentionMatches(members, 'gur', 'u1').map((m) => m.userId), ['u4']);
      expect(mentionMatches(members, '', 'u1'), hasLength(2));
    });

    test('drafts are kept per chat and cleared when empty', () {
      final c = _container();
      final drafts = c.read(chatDraftsProvider.notifier);
      drafts.save('msg:g1', 'half written');
      expect(c.read(chatDraftsProvider)['msg:g1'], 'half written');
      drafts.save('msg:g1', '  ');
      expect(c.read(chatDraftsProvider).containsKey('msg:g1'), isFalse);
    });

    testWidgets('swiping a message right starts a reply', (tester) async {
      var replied = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SwipeToReply(
              onReply: () => replied++,
              child: const SizedBox(
                width: 300,
                height: 60,
                child: Text('Hello'),
              ),
            ),
          ),
        ),
      );
      await tester.drag(find.text('Hello'), const Offset(30, 0));
      await tester.pumpAndSettle();
      expect(replied, 0);
      await tester.drag(find.text('Hello'), const Offset(120, 0));
      await tester.pumpAndSettle();
      expect(replied, 1);
    });
  });
}
