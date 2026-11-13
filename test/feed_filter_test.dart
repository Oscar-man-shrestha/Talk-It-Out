import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/api/dio_provider.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/storage/token_store.dart';
import 'package:talk_it_out/features/feed/feed_screen.dart';

void main() {
  testWidgets('the feed opens on all questions, including commented ones', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3000);
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
        child: const MaterialApp(home: FeedScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('All questions'), findsWidgets);
    // A mock post with 2 comments was hidden by the old default filter.
    expect(find.textContaining('Notes from the sprint retro.'), findsWidgets);
    // A post without comments is shown too.
    expect(
      find.textContaining('A note on how we talk about estimates.'),
      findsWidgets,
    );
  });
}
