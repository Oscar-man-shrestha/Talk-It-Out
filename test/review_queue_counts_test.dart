import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/mock/mock_ids.dart';
import 'package:talk_it_out/core/models/enums.dart';
import 'package:talk_it_out/core/models/page_result.dart';
import 'package:talk_it_out/features/review/data/mock_review_repository.dart';
import 'package:talk_it_out/features/review/data/raw_message.dart';
import 'package:talk_it_out/features/review/review_detail_screen.dart';
import 'package:talk_it_out/features/review/review_queue_screen.dart';

/// A queue with one ready rewrite, one still running and one that failed.
class _FixedQueue extends MockReviewRepository {
  _FixedQueue() : super(MockControls(delay: Duration.zero));

  RawMessage _message(String id, PipelineStatus pipeline, {String? rewrite}) =>
      RawMessage(
        id: id,
        groupId: MockIds.dashboardGroup,
        senderId: 'u-test',
        senderName: 'Test Sender',
        originalText: 'original $id',
        rewrittenText: rewrite,
        isAnonymous: false,
        pipelineStatus: pipeline,
        status: MessageStatus.pending,
        createdAt: DateTime(2026, 11, 1),
      );

  @override
  Future<PageResult<RawMessage>> listQueue(
    String groupId, {
    int? limit,
    String? cursor,
    MessageStatus status = MessageStatus.pending,
  }) async {
    if (status != MessageStatus.pending) {
      return const PageResult(items: []);
    }
    return PageResult(
      items: [
        _message('a', PipelineStatus.done, rewrite: 'a rewrite'),
        _message('b', PipelineStatus.processing),
        _message('c', PipelineStatus.failed),
      ],
    );
  }
}

Widget _detail(RawMessage message, {DateTime? retriedAt}) => ProviderScope(
  child: MaterialApp(
    home: Scaffold(
      body: ReviewDetailBody(
        message: message,
        groupAgenda: 'Dashboard improvements',
        busy: false,
        diffActive: false,
        onToggleDiff: () {},
        onAccept: () {},
        onReject: () {},
        onNewRewrite: () {},
        rewriteRequestedAt: retriedAt,
      ),
    ),
  ),
);

void main() {
  group('"taking longer than usual" on the review screen', () {
    final oldMessage = RawMessage(
      id: 'old',
      groupId: MockIds.dashboardGroup,
      senderId: 'u-test',
      senderName: 'Test Sender',
      originalText: 'sent days ago',
      isAnonymous: false,
      pipelineStatus: PipelineStatus.processing,
      status: MessageStatus.pending,
      createdAt: DateTime.now().toUtc().subtract(const Duration(days: 9)),
    );

    testWidgets('not shown right after retrying an old message', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _detail(oldMessage, retriedAt: DateTime.now().toUtc()),
      );
      expect(find.text('This is taking longer than usual'), findsNothing);
    });

    testWidgets('shown when a rewrite has waited over 2 minutes', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_detail(oldMessage));
      expect(find.text('This is taking longer than usual'), findsOneWidget);
    });
  });

  testWidgets('a failed rewrite is not counted as rewriting', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [reviewRepositoryProvider.overrideWithValue(_FixedQueue())],
        child: const MaterialApp(
          home: ReviewQueueScreen(groupId: MockIds.dashboardGroup),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('1 rewriting • 1 not available'), findsOneWidget);
    expect(
      find.textContaining('Rewrite unavailable. Use the retry button'),
      findsOneWidget,
    );

    // Unmount so the screen's refresh timer is cancelled.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
