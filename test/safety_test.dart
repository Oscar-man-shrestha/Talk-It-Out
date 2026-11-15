import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/api/dio_provider.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/storage/token_store.dart';
import 'package:talk_it_out/features/discovery/data/discovery_models.dart';
import 'package:talk_it_out/features/discovery/person_profile_screen.dart';
import 'package:talk_it_out/features/discovery/recent_people.dart';
import 'package:talk_it_out/features/discovery/safety_actions.dart';

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
  testWidgets('a profile shows who they are, shared groups and questions', (
    tester,
  ) async {
    final container = _container();
    await _pump(tester, container, const PersonProfileScreen(userId: 'u4'));
    expect(find.text('Anita Gurung'), findsOneWidget);
    expect(find.text('@anita.g'), findsWidgets);
    expect(find.text('Engineering manager'), findsOneWidget);
    expect(find.text('Questions'), findsOneWidget);
    expect(find.byKey(const ValueKey('person-add-to-group')), findsOneWidget);
  });

  testWidgets('block from the profile, then unblock', (tester) async {
    final container = _container();
    await _pump(tester, container, const PersonProfileScreen(userId: 'u4'));
    await tester.tap(find.byKey(const ValueKey('person-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Block'));
    await tester.pumpAndSettle();
    expect(find.text('Block Anita?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-block')));
    await tester.pumpAndSettle();
    expect(find.text('You blocked Anita Gurung'), findsOneWidget);

    final repo = container.read(discoveryRepositoryProvider);
    expect((await repo.blockedPeople()).map((p) => p.id), ['u4']);
    expect(
      (await repo.searchPeople('anita')).items.map((p) => p.id),
      isNot(contains('u4')),
    );

    await tester.tap(find.byKey(const ValueKey('person-unblock')));
    await tester.pumpAndSettle();
    expect(find.text('Anita Gurung'), findsOneWidget);
    expect(await repo.blockedPeople(), isEmpty);
  });

  testWidgets('blocked people list unblocks', (tester) async {
    final container = _container();
    await container.read(discoveryRepositoryProvider).block('u7');
    await _pump(tester, container, const BlockedPeopleScreen());
    expect(find.text('Sujan Karki'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('unblock-u7')));
    await tester.pumpAndSettle();
    expect(find.textContaining("haven't blocked anyone"), findsOneWidget);
  });

  test('reporting hides a question from you; undo shows it again', () async {
    final container = _container();
    final feed = container.read(feedRepositoryProvider);
    final repo = container.read(discoveryRepositoryProvider);
    final first = (await feed.listPosts()).items.first;
    await repo.reportPost(first.id, ReportReason.spam);
    expect(
      (await feed.listPosts()).items.map((p) => p.id),
      isNot(contains(first.id)),
    );
    await repo.withdrawReport(first.id);
    expect((await feed.listPosts()).items.map((p) => p.id), contains(first.id));
  });

  test('report reasons match the API', () {
    expect(ReportReason.values.map((r) => r.id), [
      'spam',
      'harassment',
      'hate',
      'self_harm',
      'misinformation',
      'other',
    ]);
  });
}
