/// One live-update signal from `GET /events` (`API.md` 41).
///
/// Signals carry ids only. Screens react by refetching through their
/// normal repositories, which enforce every privacy rule.
class LiveEvent {
  const LiveEvent(this.type, {this.groupId, this.messageId, this.postId});

  /// `chat`, `reaction`, `review`, `mine`, `members`, `groups`,
  /// `notifications`, `feed`, or the client-side `resync` (refetch
  /// everything: the stream was down and events may have been missed).
  final String type;
  final String? groupId;
  final String? messageId;
  final String? postId;

  static const resync = LiveEvent('resync');

  /// Event types the server sends; [resync] is also sent by the server
  /// when its own database listener reconnects.
  static const types = [
    'chat',
    'reaction',
    'review',
    'mine',
    'members',
    'groups',
    'notifications',
    'feed',
    'resync',
  ];

  bool get isResync => type == 'resync';

  static LiveEvent? fromSse(String event, Map<String, dynamic> data) {
    if (!types.contains(event)) return null;
    String? str(String key) => data[key] is String ? data[key] as String : null;
    return LiveEvent(
      event,
      groupId: str('group_id'),
      messageId: str('message_id'),
      postId: str('post_id'),
    );
  }

  @override
  String toString() => 'LiveEvent($type, group: $groupId)';
}
