import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/app/theme.dart';
import 'package:talk_it_out/core/mock/mock_board.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/mock/mock_ids.dart';
import 'package:talk_it_out/core/models/enums.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/features/groups/data/mock_group_repository.dart';
import 'package:talk_it_out/features/groups/data/mock_message_bridge.dart';
import 'package:talk_it_out/features/groups/data/my_message_status.dart';
import 'package:talk_it_out/features/groups/my_messages_screen.dart';

void main() {
  testWidgets('renders only own message statuses and permitted metadata', (
    tester,
  ) async {
    final bridge = MockMessageBridge()
      ..mine.addAll([
        _status('pending', MessageStatus.pending, isAnonymous: true),
        _status('accepted', MessageStatus.accepted),
        _status('rejected', MessageStatus.rejected),
      ]);

    await _pumpScreen(tester, _repository(bridge: bridge));

    expect(find.text(AppStrings.statusPending), findsOneWidget);
    expect(find.text(AppStrings.statusAccepted), findsOneWidget);
    expect(find.text(AppStrings.statusRejected), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

    expect(find.text('ORIGINAL SUBMISSION'), findsNothing);
    expect(find.text('AI SANITIZED REVISION'), findsNothing);
    expect(find.text('REJECTED DRAFT'), findsNothing);
    expect(find.text('CONTROLLER NOTE'), findsNothing);
    expect(find.text('Withdraw Draft'), findsNothing);
    expect(find.text('Edit & Resubmit'), findsNothing);
    expect(find.text('AI Ethics & Workplace Policy'), findsNothing);
  });

  testWidgets('shows loading, empty, and error states', (tester) async {
    await _pumpScreen(
      tester,
      _repository(controls: MockControls(delay: const Duration(seconds: 1))),
      settle: false,
    );
    expect(find.bySemanticsLabel(AppStrings.loading), findsOneWidget);

    final emptyBridge = MockMessageBridge()
      ..mine.add(
        _status('other', MessageStatus.pending, groupId: 'other-group'),
      );
    await _pumpScreen(tester, _repository(bridge: emptyBridge));
    expect(find.text(AppStrings.myMessagesEmpty), findsOneWidget);

    await _pumpScreen(
      tester,
      _repository(
        controls: MockControls(delay: Duration.zero, forceError: true),
      ),
    );
    expect(find.text(AppStrings.errorGeneric), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);
  });
}

MyMessageStatus _status(
  String id,
  MessageStatus status, {
  bool isAnonymous = false,
  String groupId = MockIds.notesGroup,
}) {
  return MyMessageStatus(
    id: id,
    groupId: groupId,
    status: status,
    isAnonymous: isAnonymous,
    createdAt: DateTime.utc(2026, 10, 20, 10),
  );
}

MockGroupRepository _repository({
  MockControls? controls,
  MockMessageBridge? bridge,
}) {
  return MockGroupRepository(
    controls ?? MockControls(delay: Duration.zero),
    MockBoard(),
    bridge ?? MockMessageBridge(),
  );
}

Future<void> _pumpScreen(
  WidgetTester tester,
  MockGroupRepository repository, {
  bool settle = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [groupRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        theme: lightTheme,
        home: const MyMessagesScreen(groupId: MockIds.notesGroup),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}
