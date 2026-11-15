import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:talk_it_out/core/models/user.dart';

/// An account used on this device, offered as "Continue as..." after
/// signing out, like Instagram and Facebook. Only the name and email are
/// kept: never a password or a token, so choosing one still asks for the
/// password.
class SavedAccount {
  const SavedAccount({required this.name, required this.email});

  final String name;
  final String email;

  /// "pr***@example.com": enough to recognise, not to read over a shoulder.
  String get maskedEmail {
    final at = email.indexOf('@');
    if (at <= 0) return email;
    final local = email.substring(0, at);
    final shown = local.length <= 2
        ? local.substring(0, 1)
        : local.substring(0, 2);
    return '$shown***${email.substring(at)}';
  }

  String get initials {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final letters = words.take(2).map((w) => w[0].toUpperCase()).join();
    return letters.isEmpty ? '?' : letters;
  }

  Map<String, String> toJson() => {'name': name, 'email': email};
}

/// Where saved accounts are kept. Tests override it with null (memory only).
final savedAccountsStorageProvider = Provider<FlutterSecureStorage?>(
  (ref) => const FlutterSecureStorage(),
);

class SavedAccountsNotifier extends Notifier<List<SavedAccount>> {
  static const _key = 'saved_accounts';
  static const max = 3;

  @override
  List<SavedAccount> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    final storage = ref.read(savedAccountsStorageProvider);
    if (storage == null) return;
    try {
      final raw = await storage.read(key: _key);
      if (raw == null) return;
      final loaded = [
        for (final x in jsonDecode(raw) as List)
          if (x is Map && x['email'] is String && x['name'] is String)
            SavedAccount(
              name: x['name'] as String,
              email: x['email'] as String,
            ),
      ];
      final known = {for (final a in state) a.email};
      state = [
        ...state,
        ...loaded.where((a) => !known.contains(a.email)),
      ].take(max).toList();
    } catch (_) {
      // Unreadable storage: show none rather than fail.
    }
  }

  /// Most recent first. Called after every successful sign-in.
  void remember(User user) {
    final email = user.email;
    if (email == null || email.isEmpty) return;
    final account = SavedAccount(name: user.name, email: email);
    state = [
      account,
      ...state.where((a) => a.email != email),
    ].take(max).toList();
    _save();
  }

  void forget(String email) {
    state = state.where((a) => a.email != email).toList();
    _save();
  }

  Future<void> _save() async {
    final storage = ref.read(savedAccountsStorageProvider);
    if (storage == null) return;
    try {
      await storage.write(
        key: _key,
        value: jsonEncode([for (final a in state) a.toJson()]),
      );
    } catch (_) {
      // Kept in memory for this session.
    }
  }
}

final savedAccountsProvider =
    NotifierProvider<SavedAccountsNotifier, List<SavedAccount>>(
      SavedAccountsNotifier.new,
    );
