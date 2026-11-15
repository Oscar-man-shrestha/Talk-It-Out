import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/core/share/share_links.dart';
import 'package:talk_it_out/features/feed/data/author.dart';
import 'package:talk_it_out/features/feed/data/post.dart';

void main() {
  Post post(String? title, String content) => Post(
    id: 'p9',
    author: const Author(id: 'u1', name: 'Priya'),
    title: title,
    content: content,
    nsfwFlag: false,
    reactionCount: 0,
    commentCount: 0,
    createdAt: DateTime.utc(2026, 11, 1),
  );

  test('a shared question quotes it and invites an answer', () {
    final text = questionShareText(post('How do I ask for a raise?', 'x'));
    expect(text, startsWith('"How do I ask for a raise?"'));
    expect(text, contains('Answer on Talk It Out: '));
    // Tests run off the web without APP_WEB_URL: the Play page is used.
    expect(text, endsWith(playStoreUrl));
  });

  test('long questions are shortened', () {
    final text = questionShareText(post(null, 'a' * 300));
    expect(text, contains('${'a' * 137}...'));
  });

  test('the friend invite links to the app', () {
    expect(inviteFriendsText(), endsWith(playStoreUrl));
  });
}
