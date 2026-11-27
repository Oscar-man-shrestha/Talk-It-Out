import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/features/groups/data/published_message.dart';
import 'package:talk_it_out/features/groups/group_chat_screen.dart';

PublishedMessage _msg(String? senderId, DateTime at) => PublishedMessage(
  id: 'm${at.microsecondsSinceEpoch}',
  groupId: 'g1',
  text: 'hello',
  displaySender: senderId == null
      ? null
      : DisplaySender(id: senderId, name: 'Person $senderId'),
  publishedAt: at,
);

void main() {
  final t = DateTime(2026, 11, 26, 10);

  test('messages from one named sender within 5 minutes form a run', () {
    expect(
      continuesRun(
        _msg('u1', t),
        _msg('u1', t.add(const Duration(minutes: 2))),
      ),
      isTrue,
    );
  });

  test('a different sender, a long gap or a new day breaks the run', () {
    expect(continuesRun(_msg('u1', t), _msg('u2', t)), isFalse);
    expect(
      continuesRun(
        _msg('u1', t),
        _msg('u1', t.add(const Duration(minutes: 6))),
      ),
      isFalse,
    );
    final late = DateTime(2026, 11, 26, 23, 59);
    expect(
      continuesRun(
        _msg('u1', late),
        _msg('u1', late.add(const Duration(minutes: 2))),
      ),
      isFalse,
    );
  });

  test(
    'anonymous messages never group, so nobody can tell they share an author',
    () {
      expect(continuesRun(_msg(null, t), _msg(null, t)), isFalse);
      expect(continuesRun(_msg('u1', t), _msg(null, t)), isFalse);
    },
  );
}
