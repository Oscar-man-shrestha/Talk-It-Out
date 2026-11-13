/// The reactions the backend accepts (`API.md` endpoint 33).
const kReactionEmojis = ['👍', '❤️', '🔥', '💡', '👏', '🎯'];

/// Reaction counts for one published message.
///
/// Counts only: the API never says who reacted, so a reaction reveals nothing
/// about an anonymous author or about other members.
class MessageReactions {
  const MessageReactions({
    required this.messageId,
    this.counts = const {},
    this.mine = const {},
  });

  final String messageId;
  final Map<String, int> counts;
  final Set<String> mine;

  factory MessageReactions.fromJson(Map<String, dynamic> json) {
    final rawCounts = json['reactions'];
    final rawMine = json['my_reactions'];
    return MessageReactions(
      messageId: json['message_id'] is String
          ? json['message_id'] as String
          : '',
      counts: {
        if (rawCounts is Map)
          for (final entry in rawCounts.entries)
            if (entry.key is String && entry.value is num && entry.value > 0)
              entry.key as String: (entry.value as num).toInt(),
      },
      mine: {
        if (rawMine is List)
          for (final emoji in rawMine)
            if (emoji is String) emoji,
      },
    );
  }

  /// This message's reactions after the caller toggles [emoji].
  MessageReactions toggled(String emoji) {
    final nextCounts = Map<String, int>.of(counts);
    final nextMine = Set<String>.of(mine);
    if (nextMine.remove(emoji)) {
      final left = (nextCounts[emoji] ?? 1) - 1;
      if (left <= 0) {
        nextCounts.remove(emoji);
      } else {
        nextCounts[emoji] = left;
      }
    } else {
      nextMine.add(emoji);
      nextCounts[emoji] = (nextCounts[emoji] ?? 0) + 1;
    }
    return MessageReactions(
      messageId: messageId,
      counts: nextCounts,
      mine: nextMine,
    );
  }
}
