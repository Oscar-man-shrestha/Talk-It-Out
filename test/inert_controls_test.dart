import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/mock/mock_ids.dart';
import 'package:talk_it_out/core/models/enums.dart';
import 'package:talk_it_out/features/auth/data/mock_auth_repository.dart';
import 'package:talk_it_out/features/feed/saved_posts.dart';
import 'package:talk_it_out/features/profile/data/mock_profile_repository.dart';
import 'package:talk_it_out/features/profile/data/profile.dart';
import 'package:talk_it_out/features/groups/group_chat_screen.dart';
import 'package:talk_it_out/features/review/data/mock_review_repository.dart';

void main() {
  group('review: ask for a new rewrite', () {
    test('a pending message gets a fresh rewrite', () async {
      final repo = MockReviewRepository(MockControls(delay: Duration.zero));
      await repo.requestRewrite('m201');
      final message = await repo.getMessage(MockIds.dashboardGroup, 'm201');
      expect(message.pipelineStatus, PipelineStatus.done);
      expect(message.rewrittenText, isNotEmpty);
    });

    test('a decided message cannot be rewritten again', () async {
      final repo = MockReviewRepository(MockControls(delay: Duration.zero));
      await repo.reject('m201');
      expect(
        () => repo.requestRewrite('m201'),
        throwsA(isA<RepositoryException>()),
      );
    });
  });

  test('the rewrite tone is read from and saved to the profile', () async {
    final fast = MockControls(delay: Duration.zero);
    final repo = MockProfileRepository(fast, MockAuthRepository(fast));
    final saved = await repo.updateRewriteTone('empathetic');
    expect(saved.rewriteTone, 'empathetic');
    expect((await repo.getMyProfile()).rewriteTone, 'empathetic');

    Map<String, dynamic> json(Object? tone) => {
      'user': {'id': 'u1', 'name': 'A', 'rewrite_tone': tone},
    };
    expect(Profile.fromJson(json('direct')).rewriteTone, 'direct');
    // Missing or unknown values fall back to the default.
    expect(Profile.fromJson(json(null)).rewriteTone, 'professional');
    expect(Profile.fromJson(json('rude')).rewriteTone, 'professional');
  });

  test('saved questions toggle on and off', () async {
    final container = ProviderContainer(
      overrides: [savedPostsStorageProvider.overrideWithValue(null)],
    );
    addTearDown(container.dispose);
    final saved = container.read(savedPostsProvider.notifier);
    await saved.toggle('p1');
    expect(container.read(savedPostsProvider), {'p1'});
    await saved.toggle('p2');
    await saved.toggle('p1');
    expect(container.read(savedPostsProvider), {'p2'});
  });

  testWidgets('the emoji picker inserts at the cursor', (tester) async {
    final controller = TextEditingController(text: 'Thanks all')
      ..selection = const TextSelection.collapsed(offset: 6);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showEmojiPicker(context, controller),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('emoji-picker')), findsOneWidget);
    await tester.tap(find.text('👍'));
    await tester.pumpAndSettle();
    expect(controller.text, 'Thanks👍 all');
    expect(controller.selection.baseOffset, 8);
    expect(find.byKey(const ValueKey('emoji-picker')), findsNothing);
  });
}
