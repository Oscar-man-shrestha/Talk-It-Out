import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/app/theme.dart';
import 'package:talk_it_out/features/groups/data/published_message.dart';
import 'package:talk_it_out/features/groups/group_chat_screen.dart';

PublishedMessage _from(String id, String name) => PublishedMessage(
  id: 'pm-$id',
  groupId: 'g1',
  text: 'Hello from $name',
  displaySender: DisplaySender(id: id, name: name),
  publishedAt: DateTime.utc(2026, 11, 14, 9),
);

Future<void> _pump(
  WidgetTester tester,
  PublishedMessage message, {
  String? me,
  String? controller,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: lightTheme,
      home: Scaffold(
        body: PublishedMessageTile(
          message: message,
          currentUserId: me,
          controllerId: controller,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('someone named Priya is not "me"', (tester) async {
    await _pump(tester, _from('u-priya', 'Priya'), me: 'u-oscar');
    final row = tester.widget<Row>(
      find
          .ancestor(
            of: find.text('Hello from Priya'),
            matching: find.byType(Row),
          )
          .last,
    );
    expect(row.mainAxisAlignment, MainAxisAlignment.start);
  });

  testWidgets('my own messages sit on the right', (tester) async {
    await _pump(tester, _from('u-oscar', 'Oscar'), me: 'u-oscar');
    final row = tester.widget<Row>(
      find
          .ancestor(
            of: find.text('Hello from Oscar'),
            matching: find.byType(Row),
          )
          .last,
    );
    expect(row.mainAxisAlignment, MainAxisAlignment.end);
  });

  testWidgets('the Controller badge follows the controller id, not the name', (
    tester,
  ) async {
    await _pump(
      tester,
      _from('u-priya', 'Priya'),
      me: 'u-x',
      controller: 'u-priya',
    );
    expect(find.text('CONTROLLER'), findsOneWidget);

    await _pump(
      tester,
      _from('u-sam', 'Sam the Controller'),
      me: 'u-x',
      controller: 'u-priya',
    );
    expect(find.text('CONTROLLER'), findsNothing);
  });
}
