import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/features/auth/session_controller.dart';
import 'package:talk_it_out/features/groups/data/published_message.dart';
import 'package:talk_it_out/features/premium/premium_providers.dart';

/// Device storage for Premium chat preferences. Tests override it with null
/// (memory only), like saved accounts.
final chatPrefsStorageProvider = Provider<FlutterSecureStorage?>(
  (ref) => const FlutterSecureStorage(),
);

// ─── Chat themes ────────────────────────────────────────────────────────────

/// Bubble colours for your own messages.
enum BubbleAccent {
  ink('Ink', [Color(0xFF2B2B30), Brand.ink]),
  ocean('Ocean', [Color(0xFF2563EB), Color(0xFF1E3A8A)]),
  forest('Forest', [Color(0xFF16A34A), Color(0xFF14532D)]),
  plum('Plum', [Color(0xFF9333EA), Color(0xFF581C87)]),
  sunset('Sunset', [Color(0xFFF97316), Color(0xFF9A3412)]),
  rose('Rose', [Color(0xFFE11D48), Color(0xFF9F1239)]);

  const BubbleAccent(this.label, this.colors);
  final String label;
  final List<Color> colors;
}

/// Chat backgrounds.
enum ChatWallpaperStyle {
  dots('Dots'),
  plain('Plain'),
  grid('Grid'),
  waves('Waves');

  const ChatWallpaperStyle(this.label);
  final String label;
}

typedef ChatThemeChoice = ({BubbleAccent accent, ChatWallpaperStyle wallpaper});

const defaultChatTheme = (
  accent: BubbleAccent.ink,
  wallpaper: ChatWallpaperStyle.dots,
);

class ChatThemeNotifier extends Notifier<ChatThemeChoice> {
  static const _key = 'chat_theme';

  @override
  ChatThemeChoice build() {
    _load();
    return defaultChatTheme;
  }

  Future<void> _load() async {
    final storage = ref.read(chatPrefsStorageProvider);
    if (storage == null) return;
    try {
      final raw = await storage.read(key: _key);
      if (raw == null) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      state = (
        accent:
            BubbleAccent.values.asNameMap()[json['accent']] ?? BubbleAccent.ink,
        wallpaper:
            ChatWallpaperStyle.values.asNameMap()[json['wallpaper']] ??
            ChatWallpaperStyle.dots,
      );
    } catch (_) {
      // Unreadable storage: keep the default.
    }
  }

  Future<void> choose({
    BubbleAccent? accent,
    ChatWallpaperStyle? wallpaper,
  }) async {
    state = (
      accent: accent ?? state.accent,
      wallpaper: wallpaper ?? state.wallpaper,
    );
    try {
      await ref
          .read(chatPrefsStorageProvider)
          ?.write(
            key: _key,
            value: jsonEncode({
              'accent': state.accent.name,
              'wallpaper': state.wallpaper.name,
            }),
          );
    } catch (_) {
      // Kept for this session.
    }
  }
}

final chatThemeChoiceProvider =
    NotifierProvider<ChatThemeNotifier, ChatThemeChoice>(ChatThemeNotifier.new);

/// The theme actually used in chats: the chosen one with Premium, the
/// default without (a lapsed subscription returns to the default look).
final chatThemeProvider = Provider<ChatThemeChoice>((ref) {
  return ref.watch(isPremiumProvider)
      ? ref.watch(chatThemeChoiceProvider)
      : defaultChatTheme;
});

// ─── Starred messages ───────────────────────────────────────────────────────

/// A published message saved on this device. Published text only (what the
/// whole group already sees), never raw text; anonymous stays anonymous.
class StarredMessage {
  const StarredMessage({
    required this.id,
    required this.groupId,
    required this.text,
    required this.sender,
    required this.at,
  });

  final String id;
  final String groupId;
  final String text;

  /// The sender as the group sees it ("Anonymous user" when anonymous).
  final String sender;
  final DateTime at;

  Map<String, Object> toJson() => {
    'id': id,
    'group_id': groupId,
    'text': text,
    'sender': sender,
    'at': at.toIso8601String(),
  };

  static StarredMessage? fromJson(Object? json) {
    if (json is! Map) return null;
    final at = DateTime.tryParse('${json['at']}');
    if (json['id'] is! String || json['group_id'] is! String || at == null) {
      return null;
    }
    return StarredMessage(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      text: '${json['text'] ?? ''}',
      sender: '${json['sender'] ?? ''}',
      at: at,
    );
  }
}

class StarredNotifier extends Notifier<List<StarredMessage>> {
  /// Kept per signed-in account on this device.
  String get _key => 'starred_${ref.read(sessionProvider).value?.id ?? 'none'}';

  @override
  List<StarredMessage> build() {
    ref.watch(sessionProvider.select((s) => s.value?.id));
    _load();
    return const [];
  }

  Future<void> _load() async {
    final storage = ref.read(chatPrefsStorageProvider);
    if (storage == null) return;
    try {
      final raw = await storage.read(key: _key);
      if (raw == null) return;
      state = [
        for (final item in jsonDecode(raw) as List)
          ?StarredMessage.fromJson(item),
      ];
    } catch (_) {
      // Unreadable storage: show none.
    }
  }

  bool isStarred(String messageId) => state.any((m) => m.id == messageId);

  /// Stars or unstars [message]; [senderLabel] is what the group sees.
  Future<void> toggle(PublishedMessage message, String senderLabel) async {
    state = isStarred(message.id)
        ? state.where((m) => m.id != message.id).toList()
        : [
            StarredMessage(
              id: message.id,
              groupId: message.groupId,
              text: message.text,
              sender: senderLabel,
              at: message.publishedAt,
            ),
            ...state,
          ];
    await _save();
  }

  Future<void> remove(String messageId) async {
    state = state.where((m) => m.id != messageId).toList();
    await _save();
  }

  Future<void> _save() async {
    try {
      await ref
          .read(chatPrefsStorageProvider)
          ?.write(
            key: _key,
            value: jsonEncode([for (final m in state) m.toJson()]),
          );
    } catch (_) {
      // Kept for this session.
    }
  }
}

final starredProvider = NotifierProvider<StarredNotifier, List<StarredMessage>>(
  StarredNotifier.new,
);
