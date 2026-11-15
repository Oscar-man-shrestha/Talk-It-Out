import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/api/dio_provider.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/mock/mock_ids.dart';
import 'package:talk_it_out/core/storage/token_store.dart';
import 'package:talk_it_out/features/groups/catch_up.dart';

void main() {
  test('parses the server summary', () {
    final s = CatchUp.fromJson({
      'message_count': 12,
      'highlights': ['Reviews take three days.', 7],
      'open_questions': ['Who owns on-call?'],
      'key_topics': ['review'],
      'themes': [
        {'id': 'engineering', 'label': 'Engineering & tech', 'emoji': '💻'},
      ],
    });
    expect(s.messageCount, 12);
    expect(s.highlights, ['Reviews take three days.']);
    expect(s.themes, ['💻 Engineering & tech']);
    expect(CatchUp.fromJson(const {}).isEmpty, isTrue);
  });

  testWidgets('the sheet shows highlights without names', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(
            MemoryTokenStore()..value = 'mock-token',
          ),
          mockControlsProvider.overrideWithValue(
            MockControls(delay: Duration.zero),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: CatchUpSheet(groupId: MockIds.notesGroup)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Catch up'), findsOneWidget);
    expect(find.textContaining('Names are never included'), findsOneWidget);
    expect(
      find
              .byKey(const ValueKey('catch-up-highlight-0'))
              .evaluate()
              .isNotEmpty ||
          find.byKey(const ValueKey('catch-up-empty')).evaluate().isNotEmpty,
      isTrue,
    );
  });
}
