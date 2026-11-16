import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/api/dio_provider.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/mock/mock_ids.dart';
import 'package:talk_it_out/core/storage/token_store.dart';
import 'package:talk_it_out/features/groups/groups_screen.dart';

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
  test('accepting joins the group; declining does not', () async {
    final repo = _container().read(groupRepositoryProvider);
    final invites = await repo.listMyInvitations();
    expect(invites.single.agenda, 'Design critique');
    expect(
      (await repo.listGroups()).items.map((g) => g.id),
      isNot(contains('g3')),
    );
    final groupId = await repo.acceptInvitation(invites.single.id);
    expect((await repo.listGroups()).items.map((g) => g.id), contains(groupId));
    final members = (await repo.listMembers(groupId)).items;
    expect(members.map((m) => m.userId), contains(MockIds.priya));
    expect(await repo.listMyInvitations(), isEmpty);
  });

  test('declining leaves you out', () async {
    final repo = _container().read(groupRepositoryProvider);
    final inv = (await repo.listMyInvitations()).single;
    await repo.declineInvitation(inv.id);
    expect(await repo.listMyInvitations(), isEmpty);
    expect(
      (await repo.listGroups()).items.map((g) => g.id),
      isNot(contains(inv.groupId)),
    );
  });

  test('a controller cancels an invitation not answered yet', () async {
    final repo = _container().read(groupRepositoryProvider);
    await repo.addMember(MockIds.dashboardGroup, userId: 'u4');
    final pending = await repo.listGroupInvitations(MockIds.dashboardGroup);
    expect(pending.single.userId, 'u4');
    await repo.cancelInvitation(MockIds.dashboardGroup, pending.single.id);
    expect(await repo.listGroupInvitations(MockIds.dashboardGroup), isEmpty);
  });

  testWidgets('Groups shows the invitation with Accept and Decline', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: _container(),
        child: const MaterialApp(home: GroupsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('group-invitations')), findsOneWidget);
    expect(find.text('Design critique'), findsOneWidget);
    expect(find.textContaining('You join only if you accept'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('decline-rinv1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('group-invitations')), findsNothing);
  });
}
