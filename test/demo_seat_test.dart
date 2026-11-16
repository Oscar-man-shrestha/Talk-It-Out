import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/api/dio_provider.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/mock/mock_ids.dart';
import 'package:talk_it_out/core/storage/token_store.dart';

void main() {
  test('a new demo account takes the sample seat under its own name', () async {
    final c = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
        mockControlsProvider.overrideWithValue(
          MockControls(delay: Duration.zero),
        ),
      ],
    );
    addTearDown(c.dispose);
    final session = await c
        .read(authRepositoryProvider)
        .register(
          name: 'Maya Tamang',
          email: 'maya@demo.test',
          password: 'secret123',
        );
    expect(session.user.id, MockIds.priya);
    expect(session.user.name, 'Maya Tamang');

    // Your questions, group membership and chat messages carry your name.
    final own = await c.read(feedRepositoryProvider).getPost(MockIds.ownPost);
    expect(own.author.name, 'Maya Tamang');
    final members =
        (await c.read(groupRepositoryProvider).listMembers(MockIds.notesGroup))
            .items;
    expect(
      members.singleWhere((m) => m.userId == MockIds.priya).name,
      'Maya Tamang',
    );
    final messages =
        (await c.read(groupRepositoryProvider).listMessages(MockIds.notesGroup))
            .items;
    for (final m in messages.where(
      (m) => m.displaySender?.id == MockIds.priya,
    )) {
      expect(m.displaySender!.name, 'Maya Tamang');
    }
    // Anonymous messages stay anonymous.
    expect(messages.where((m) => m.displaySender == null), isNotEmpty);
  });
}
