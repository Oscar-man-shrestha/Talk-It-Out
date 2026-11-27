import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/app/theme.dart';
import 'package:talk_it_out/core/models/enums.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/features/groups/composer_helpers.dart';
import 'package:talk_it_out/features/review/data/raw_message.dart';
import 'package:talk_it_out/features/review/moderation_notes.dart';

Widget _app(Widget child) => MaterialApp(
  theme: lightTheme,
  home: Scaffold(body: child),
);

RawMessage _raw({
  List<String> flags = const [],
  String? errorCode,
  PipelineStatus status = PipelineStatus.done,
  String? rewrite = 'Please fix the login.',
}) => RawMessage(
  id: 'r1',
  groupId: 'g1',
  senderId: 'u1',
  senderName: 'Sam',
  originalText: 'fix the login you idiots',
  rewrittenText: rewrite,
  isAnonymous: false,
  pipelineStatus: status,
  status: MessageStatus.pending,
  createdAt: DateTime.utc(2026, 11, 26, 9),
  moderationFlags: flags,
  rewriteErrorCode: errorCode,
);

void main() {
  group('Enter sends', () {
    Future<(TextEditingController, List<int>)> pump(WidgetTester tester) async {
      final controller = TextEditingController();
      final sent = <int>[];
      await tester.pumpWidget(
        _app(
          EnterToSend(
            controller: controller,
            onSend: () => sent.add(1),
            child: TextField(controller: controller, maxLines: 5, minLines: 1),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      return (controller, sent);
    }

    testWidgets('Enter sends a message', (tester) async {
      final (controller, sent) = await pump(tester);
      await tester.enterText(find.byType(TextField), 'hello team');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(sent, [1]);
      expect(controller.text, 'hello team');
    });

    testWidgets('Shift+Enter does not send', (tester) async {
      final (_, sent) = await pump(tester);
      await tester.enterText(find.byType(TextField), 'line one');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(sent, isEmpty);
    });

    testWidgets('an empty box never sends', (tester) async {
      final (_, sent) = await pump(tester);
      await tester.enterText(find.byType(TextField), '   ');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(sent, isEmpty);
    });
  });

  group('moderation flags and rewrite reasons (controller only)', () {
    testWidgets('flags show as advisory chips', (tester) async {
      await tester.pumpWidget(
        _app(
          ModerationFlagChips(
            message: _raw(flags: const ['abusive_language', 'self_harm']),
          ),
        ),
      );
      expect(find.text('Abusive language'), findsOneWidget);
      expect(find.text('May need support'), findsOneWidget);
    });

    testWidgets('no flags, nothing shown', (tester) async {
      await tester.pumpWidget(_app(ModerationFlagChips(message: _raw())));
      expect(find.byType(Wrap), findsNothing);
    });

    testWidgets('a missing rewrite says why', (tester) async {
      await tester.pumpWidget(
        _app(
          RewriteReasonNote(
            message: _raw(
              status: PipelineStatus.failed,
              rewrite: null,
              errorCode: 'unsupported_language',
            ),
          ),
        ),
      );
      expect(
        find.textContaining('only rephrases messages written in English'),
        findsOneWidget,
      );
    });

    test('every pipeline code has a plain reason; unknown codes fall back', () {
      const codes = [
        'unsupported_language',
        'input_too_long',
        'intent_not_preserved',
        'abusive_language_kept',
        'model_refused',
        'output_too_long',
        'model_timeout',
        'worker_crash',
        null,
      ];
      for (final code in codes) {
        final reason = AppStrings.rewriteReason(code);
        expect(reason, isNotEmpty);
        expect(reason, isNot(contains('_')), reason: '$code reads as words');
      }
    });
  });
}
