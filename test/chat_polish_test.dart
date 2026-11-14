import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/features/groups/group_chat_screen.dart';

void main() {
  test('emoji-only messages are recognised (1 to 3 emoji, nothing else)', () {
    for (final yes in [
      '😂',
      '👍🏽',
      '🇳🇵',
      '❤️',
      '❤️‍🔥',
      '😂😂😂',
      '🎉 🎉',
    ]) {
      expect(isEmojiOnly(yes), isTrue, reason: yes);
    }
    for (final no in ['ok', '😂 lol', '😂😂😂😂', '', '1', 'hi!']) {
      expect(isEmojiOnly(no), isFalse, reason: no);
    }
  });

  test('date dividers say Today, Yesterday, a weekday, or a date', () {
    final now = DateTime(2026, 11, 14, 18);
    expect(dayLabel(DateTime(2026, 11, 14, 9), now: now), 'Today');
    expect(dayLabel(DateTime(2026, 11, 13, 23), now: now), 'Yesterday');
    expect(dayLabel(DateTime(2026, 11, 10, 12), now: now), 'Tuesday');
    expect(dayLabel(DateTime(2026, 10, 2, 12), now: now), '2 Oct');
    expect(dayLabel(DateTime(2025, 10, 2, 12), now: now), '2 Oct 2025');
    expect(
      sameDay(DateTime(2026, 11, 14, 1), DateTime(2026, 11, 14, 23)),
      isTrue,
    );
  });
}
