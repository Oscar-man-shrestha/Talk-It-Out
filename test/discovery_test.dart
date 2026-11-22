import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/api/dio_provider.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/mock/mock_ids.dart';
import 'package:talk_it_out/core/storage/token_store.dart';
import 'package:talk_it_out/features/discovery/add_members_sheet.dart';
import 'package:talk_it_out/features/discovery/data/discovery_models.dart';
import 'package:talk_it_out/features/discovery/data/name_match.dart';
import 'package:talk_it_out/features/discovery/discovery_providers.dart';
import 'package:talk_it_out/features/discovery/handle_editor.dart';
import 'package:talk_it_out/features/discovery/interest_picker_screen.dart';
import 'package:talk_it_out/features/discovery/recent_people.dart';
import 'package:talk_it_out/features/feed/feed_screen.dart';
import 'package:talk_it_out/features/groups/members_screen.dart';

ProviderContainer _container() {
  final container = ProviderContainer(
    overrides: [
      tokenStoreProvider.overrideWithValue(
        MemoryTokenStore()..value = 'mock-token',
      ),
      mockControlsProvider.overrideWithValue(
        MockControls(delay: Duration.zero),
      ),
      recentPeopleStorageProvider.overrideWithValue(null),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _pump(
  WidgetTester tester,
  ProviderContainer container,
  Widget home,
) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: home),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('name matching (demo port)', () {
    test('prefix, typo and sound-alike', () {
      expect(matchName('roh', 'Rohan Shrestha')?.kind, 'prefix');
      expect(matchName('shre', 'Rohan Shrestha')?.kind, 'prefix');
      expect(matchName('rhoan', 'Rohan Shrestha')?.kind, 'similar');
      expect(matchName('catherine', 'Katherine Rai'), isNotNull);
      expect(
        matchName('@kat.r', 'Katherine Rai', handle: 'kat.rai')?.kind,
        'prefix',
      );
      expect(matchName('zzzz', 'Rohan Shrestha'), isNull);
      expect(soundKey('Shrestha'), soundKey('Shresta'));
      expect(editDistance('rhoan', 'rohan'), 1);
    });
  });

  group('models', () {
    test('person subtitle reads like Instagram', () {
      final p = PersonResult.fromJson({
        'id': 'x',
        'name': 'Anita Gurung',
        'handle': 'anita.g',
        'headline': 'Engineering manager',
        'shared_groups': 2,
        'in_group': false,
      });
      expect(
        p.subtitle,
        '@anita.g · Engineering manager · In 2 of your groups',
      );
      expect(p.initials, 'AG');
    });

    test('a For You item keeps the post and its reason', () {
      final item = RankedPost.fromJson({
        'id': 'p1',
        'author': {'id': 'u1', 'name': 'A'},
        'content': 'Body',
        'nsfw_flag': false,
        'other_flags': <String, dynamic>{},
        'reaction_count': 2,
        'my_reaction': null,
        'comment_count': 1,
        'created_at': '2026-11-14T10:00:00.000Z',
        'reason': {
          'kind': 'interest',
          'text': 'Because you follow Startups',
          'interest': 'startups',
        },
        'interests': ['startups'],
      });
      expect(item.post.id, 'p1');
      expect(item.reason?.text, 'Because you follow Startups');
      expect(item.interests, ['startups']);
    });
  });

  testWidgets('Add members: typo search, multi-select, add', (tester) async {
    final container = _container();
    await _pump(
      tester,
      container,
      const Scaffold(body: AddMembersSheet(groupId: MockIds.dashboardGroup)),
    );

    // Suggested people show before typing; Rohan is already a member.
    expect(find.text('Suggested'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('add-members-search')),
      'anitta',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.textContaining('Anita'), findsWidgets);
    expect(find.textContaining('look or sound similar'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('person-u4')));
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('add-members-search')),
      'kat',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('person-u6')));
    await tester.pump();
    expect(find.text('Invite (2)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-members-confirm')));
    await tester.pumpAndSettle();
    // Asked first: both are invited, neither is a member until they accept.
    final repo = container.read(groupRepositoryProvider);
    final members = (await repo.listMembers(MockIds.dashboardGroup)).items
        .map((m) => m.userId);
    expect(members, isNot(contains('u4')));
    final invited = (await repo.listGroupInvitations(MockIds.dashboardGroup))
        .map((i) => i.userId);
    expect(invited, containsAll(['u4', 'u6']));
    // Both now show as Recent, on this device only.
    expect(
      container.read(recentPeopleProvider).map((p) => p.id),
      containsAll(['u4', 'u6']),
    );
  });

  testWidgets('Add members: someone already invited shows "Invited"', (
    tester,
  ) async {
    final container = _container();
    await container
        .read(groupRepositoryProvider)
        .addMember(MockIds.dashboardGroup, userId: 'u4');
    await _pump(
      tester,
      container,
      const Scaffold(body: AddMembersSheet(groupId: MockIds.dashboardGroup)),
    );
    // People not on the app yet can be invited with a link.
    expect(find.byKey(const ValueKey('add-members-link')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('add-members-search')),
      'anita',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    final tile = find.byKey(const ValueKey('person-u4'));
    expect(
      find.descendant(of: tile, matching: find.text('Invited')),
      findsOneWidget,
    );
    // Tapping does not select them again (no error later).
    await tester.tap(tile);
    await tester.pump();
    expect(find.text('Invite'), findsOneWidget);
    expect(find.text('Invite (1)'), findsNothing);
  });

  testWidgets('Members: cancelling an invitation asks first, then confirms', (
    tester,
  ) async {
    final container = _container();
    await container
        .read(groupRepositoryProvider)
        .addMember(MockIds.dashboardGroup, userId: 'u4');
    await _pump(
      tester,
      container,
      const MembersScreen(groupId: MockIds.dashboardGroup),
    );
    expect(find.text('Invited (1)'), findsOneWidget);
    expect(find.text('Invited just now'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('cancel-invitation-inv1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Cancel the invitation to'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-cancel-invitation')));
    await tester.pumpAndSettle();

    expect(find.text('Invited (1)'), findsNothing);
    expect(find.textContaining('cancelled.'), findsOneWidget);
    final left = await container
        .read(groupRepositoryProvider)
        .listGroupInvitations(MockIds.dashboardGroup);
    expect(left, isEmpty);
  });

  testWidgets('Interest picker needs 3 picks, then saves', (tester) async {
    final container = _container();
    await _pump(tester, container, const InterestPickerScreen(firstRun: true));
    expect(find.text('What are you into?'), findsOneWidget);
    expect(find.text('Pick 3 more'), findsOneWidget);
    for (final id in ['career_growth', 'wellbeing', 'startups']) {
      await tester.tap(find.byKey(ValueKey('interest-$id')));
      await tester.pump();
    }
    expect(find.text('Continue'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('interests-continue')));
    await tester.pumpAndSettle();
    final saved = await container
        .read(discoveryRepositoryProvider)
        .getInterests();
    expect(saved.chosen, isTrue);
    expect(saved.picked, ['career_growth', 'wellbeing', 'startups']);
  });

  testWidgets('For You explains each post and hides "Not interested"', (
    tester,
  ) async {
    final container = _container();
    container.read(interestPromptShownProvider.notifier).set();
    await container.read(discoveryRepositoryProvider).setInterests([
      'engineering',
    ]);
    await _pump(tester, container, const FeedScreen());

    expect(find.text('For you'), findsOneWidget);
    expect(
      find.textContaining('Because you follow Engineering & tech'),
      findsWidgets,
    );
    final first = container.read(forYouProvider).value!.first;

    await tester.tap(find.byKey(ValueKey('post-more-${first.post.id}')));
    await tester.pumpAndSettle();
    expect(find.text("Why you're seeing this"), findsOneWidget);
    await tester.tap(find.text('Not interested'));
    await tester.pumpAndSettle();
    expect(
      container.read(forYouProvider).value!.map((r) => r.post.id),
      isNot(contains(first.post.id)),
    );
    expect(find.textContaining('fewer posts like this'), findsOneWidget);
  });

  testWidgets('Handle editor checks availability and saves', (tester) async {
    final container = _container();
    await _pump(tester, container, const Scaffold(body: HandleEditor()));
    // Taken by a demo person: suggestions appear.
    await tester.enterText(find.byKey(const ValueKey('handle-field')), 'sujan');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('That handle is taken.'), findsOneWidget);
    expect(find.text('Try one of these'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('handle-field')),
      'priya.new',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Available'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('handle-save')));
    await tester.pumpAndSettle();
    expect(
      (await container.read(discoveryRepositoryProvider).getHandle()).handle,
      'priya.new',
    );
  });

  test('personalisation off: For You stops using interests', () async {
    final container = _container();
    final repo = container.read(discoveryRepositoryProvider);
    await repo.setInterests(['engineering']);
    final on = (await repo.forYou()).items;
    expect(on.any((r) => r.reason?.kind == 'interest'), isTrue);
    await repo.setPersonalized(false);
    expect((await repo.getInterests()).personalized, isFalse);
    final off = (await repo.forYou()).items;
    expect(off.every((r) => r.reason?.kind != 'interest'), isTrue);
  });

  test('similar questions find an existing question', () async {
    final container = _container();
    final repo = container.read(discoveryRepositoryProvider);
    final posts =
        (await container.read(feedRepositoryProvider).listPosts()).items;
    final target = posts.first;
    final similar = await repo.similarQuestions(
      title: target.title,
      content: target.content,
    );
    expect(similar.map((q) => q.id), contains(target.id));
    expect(await repo.similarQuestions(content: 'hi'), isEmpty);
  });
}
