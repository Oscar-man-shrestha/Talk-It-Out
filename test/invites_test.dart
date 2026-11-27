import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/api/dio_provider.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/mock/mock_ids.dart';
import 'package:talk_it_out/core/models/enums.dart';
import 'package:talk_it_out/core/storage/token_store.dart';
import 'package:talk_it_out/features/invites/invite_sheet.dart';
import 'package:talk_it_out/features/invites/join_group_screen.dart';

ProviderContainer _container() {
  final container = ProviderContainer(
    overrides: [
      tokenStoreProvider.overrideWithValue(
        MemoryTokenStore()..value = 'mock-token',
      ),
      mockControlsProvider.overrideWithValue(
        MockControls(delay: Duration.zero),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _pump(WidgetTester tester, ProviderContainer c, Widget w) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(home: Scaffold(body: w)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('a link lets someone join once; revoked links stop working', () async {
    final c = _container();
    final repo = c.read(inviteRepositoryProvider);
    final board = c.read(mockBoardProvider);
    // A group the demo user is not in yet.
    board.membersByGroup[MockIds.dashboardGroup] = [
      for (final m in board.membersByGroup[MockIds.dashboardGroup]!)
        if (m.userId != MockIds.priya) m,
    ];
    final link = await repo.createInvite(MockIds.dashboardGroup, maxUses: 1);
    expect(link.code, matches(RegExp(r'^[a-z2-9]{10}$')));
    expect(link.url, endsWith('/#/join/${link.code}'));

    final preview = await repo.previewInvite(link.code);
    expect(preview.alreadyMember, isFalse);
    expect(await repo.acceptInvite(link.code), MockIds.dashboardGroup);
    final me = board.membersByGroup[MockIds.dashboardGroup]!.firstWhere(
      (m) => m.userId == MockIds.priya,
    );
    expect(me.role, GroupRole.contributor);
    // Used up, but joining again as a member still works.
    expect(await repo.acceptInvite(link.code), MockIds.dashboardGroup);

    final other = await repo.createInvite(MockIds.notesGroup);
    await repo.revokeInvite(MockIds.notesGroup, other.code);
    expect(
      () => repo.previewInvite(other.code),
      throwsA(isA<RepositoryException>()),
    );
    expect(await repo.listInvites(MockIds.notesGroup), isEmpty);
  });

  test('the share message names the group and carries the link', () async {
    final c = _container();
    final link = await c
        .read(inviteRepositoryProvider)
        .createInvite(MockIds.notesGroup);
    final text = inviteMessage('Sprint retro', link);
    expect(text, contains('"Sprint retro"'));
    expect(text, endsWith(link.url));
  });

  testWidgets('the sheet makes a link, shows a QR code and turns it off', (
    tester,
  ) async {
    final c = _container();
    await _pump(
      tester,
      c,
      const InviteSheet(groupId: MockIds.dashboardGroup, agenda: 'Dashboards'),
    );
    await tester.tap(find.byKey(const ValueKey('invite-expiry-30 days')));
    await tester.tap(find.byKey(const ValueKey('invite-uses-10 people')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invite-create')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('invite-link-box')), findsOneWidget);
    expect(find.textContaining('0 of 10 joined'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('invite-qr')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('invite-qr-image')), findsOneWidget);

    final links = await c
        .read(inviteRepositoryProvider)
        .listInvites(MockIds.dashboardGroup);
    final revoke = find.byKey(ValueKey('invite-revoke-${links.single.code}'));
    await tester.ensureVisible(revoke);
    await tester.tap(revoke);
    await tester.pumpAndSettle();
    expect(
      await c
          .read(inviteRepositoryProvider)
          .listInvites(MockIds.dashboardGroup),
      isEmpty,
    );
  });

  testWidgets('the join screen explains anonymity and handles bad links', (
    tester,
  ) async {
    final c = _container();
    final link = await c
        .read(inviteRepositoryProvider)
        .createInvite(MockIds.notesGroup);
    await _pump(tester, c, JoinGroupScreen(code: link.code));
    expect(find.text('Priya invited you to'), findsOneWidget);
    expect(
      find.textContaining('can see who sent anonymous ones'),
      findsOneWidget,
    );
    // The demo user is already in this group.
    expect(find.text("You're in. Open the group"), findsOneWidget);

    await _pump(tester, c, const JoinGroupScreen(code: 'zzzzzzzzzz'));
    expect(find.textContaining('expired or was turned off'), findsOneWidget);
  });
}
