import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:talk_it_out/features/feed/data/post.dart';

/// The app's Google Play page (the application ID is permanent).
const playStoreUrl =
    'https://play.google.com/store/apps/details?id=com.talkitout.talk_it_out';

/// Where the web app lives: the current page on the web, otherwise the
/// `APP_WEB_URL` build setting (empty when the build did not set one).
String webAppBase() {
  if (kIsWeb) {
    final base = Uri.base;
    return '${base.origin}${base.path}';
  }
  const configured = String.fromEnvironment('APP_WEB_URL');
  return configured;
}

/// A link that opens a question, or null when there is no web address.
String? questionLink(String postId) {
  final base = webAppBase();
  if (base.isEmpty) return null;
  return '${base.replaceAll(RegExp(r'/+$'), '')}/#/feed/$postId';
}

/// What people send when they share a question.
String questionShareText(Post post) {
  final title = post.title ?? post.content;
  final short = title.length > 140 ? '${title.substring(0, 137)}...' : title;
  final link = questionLink(post.id) ?? playStoreUrl;
  return '"$short"\n\nWhat would you say? Answer on Talk It Out: $link';
}

/// What people send when they invite friends to the app.
String inviteFriendsText() {
  final base = webAppBase();
  final link = base.isEmpty ? playStoreUrl : base;
  return 'I use Talk It Out to say what matters at work: anonymous when it '
      'needs to be, rewritten calmly by AI, and reviewed before anyone sees '
      'it. Join me: $link';
}

/// Opens the system share sheet. Returns false when there is none (some
/// desktop browsers), so the caller can copy instead.
Future<bool> shareText(String text, {String? subject}) async {
  try {
    final result = await SharePlus.instance.share(
      ShareParams(text: text, subject: subject),
    );
    return result.status != ShareResultStatus.unavailable;
  } catch (_) {
    return false;
  }
}
