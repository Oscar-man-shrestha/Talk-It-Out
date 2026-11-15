import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:talk_it_out/features/auth/session_controller.dart';
import 'package:talk_it_out/features/discovery/data/discovery_models.dart';

/// Where recently added people are kept on this device. Tests override it
/// with null to keep the list in memory only.
final recentPeopleStorageProvider = Provider<FlutterSecureStorage?>(
  (ref) => const FlutterSecureStorage(),
);

/// People this account recently added to a group, newest first, like
/// Instagram's "Recent". Kept on this device only; never sent anywhere.
class RecentPeopleNotifier extends Notifier<List<PersonResult>> {
  static const max = 8;
  String? _key;

  @override
  List<PersonResult> build() {
    final userId = ref.watch(sessionProvider).value?.id;
    _key = userId == null ? null : 'recent_people:$userId';
    if (_key != null) _load(_key!);
    return const [];
  }

  Future<void> _load(String key) async {
    final storage = ref.read(recentPeopleStorageProvider);
    if (storage == null) return;
    try {
      final raw = await storage.read(key: key);
      if (raw == null || key != _key) return;
      final list = [
        for (final x in jsonDecode(raw) as List)
          if (x is Map) PersonResult.fromJson(Map<String, dynamic>.from(x)),
      ];
      final known = {for (final p in state) p.id};
      state = [
        ...state,
        ...list.where((p) => !known.contains(p.id)),
      ].take(max).toList();
    } catch (_) {
      // Unreadable storage: start empty rather than fail.
    }
  }

  void addAll(Iterable<PersonResult> people) {
    final added = people.toList();
    final ids = {for (final p in added) p.id};
    state = [
      ...added,
      ...state.where((p) => !ids.contains(p.id)),
    ].take(max).toList();
    _save();
  }

  void clear() {
    state = const [];
    _save();
  }

  Future<void> _save() async {
    final storage = ref.read(recentPeopleStorageProvider);
    final key = _key;
    if (storage == null || key == null) return;
    try {
      await storage.write(
        key: key,
        value: jsonEncode([
          for (final p in state)
            {
              'id': p.id,
              'name': p.name,
              'handle': p.handle,
              'headline': p.headline,
            },
        ]),
      );
    } catch (_) {
      // Kept in memory for this session even if the device refuses.
    }
  }
}

final recentPeopleProvider =
    NotifierProvider<RecentPeopleNotifier, List<PersonResult>>(
      RecentPeopleNotifier.new,
    );
