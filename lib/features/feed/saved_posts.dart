import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:talk_it_out/features/auth/session_controller.dart';

/// Where saved (bookmarked) questions are kept on this device. Tests
/// override it with null to keep bookmarks in memory only.
final savedPostsStorageProvider = Provider<FlutterSecureStorage?>(
  (ref) => const FlutterSecureStorage(),
);

/// The ids of the questions the signed-in user saved on this device.
/// Saved posts are a private reading list: nothing is sent to the server.
class SavedPostsNotifier extends Notifier<Set<String>> {
  String? _key;

  @override
  Set<String> build() {
    final userId = ref.watch(sessionProvider).value?.id;
    _key = userId == null ? null : 'saved_posts:$userId';
    if (_key != null) _load(_key!);
    return const {};
  }

  Future<void> _load(String key) async {
    final storage = ref.read(savedPostsStorageProvider);
    if (storage == null) return;
    try {
      final raw = await storage.read(key: key);
      if (raw == null || key != _key) return;
      final ids = (jsonDecode(raw) as List).whereType<String>().toSet();
      state = {...ids, ...state};
    } catch (_) {
      // Unreadable storage: start with an empty list rather than fail.
    }
  }

  bool isSaved(String postId) => state.contains(postId);

  Future<void> toggle(String postId) async {
    final next = {...state};
    if (!next.remove(postId)) next.add(postId);
    state = next;
    final storage = ref.read(savedPostsStorageProvider);
    final key = _key;
    if (storage == null || key == null) return;
    try {
      await storage.write(key: key, value: jsonEncode(next.toList()));
    } catch (_) {
      // Kept in memory for this session even if the device refuses.
    }
  }
}

final savedPostsProvider = NotifierProvider<SavedPostsNotifier, Set<String>>(
  SavedPostsNotifier.new,
);
