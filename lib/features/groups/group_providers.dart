import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/models/group.dart';
import 'package:talk_it_out/core/models/group_member.dart';
import 'package:talk_it_out/core/realtime/realtime_client.dart';
import 'package:talk_it_out/features/auth/session_controller.dart';
import 'package:talk_it_out/features/groups/data/message_reactions.dart';
import 'package:talk_it_out/features/groups/data/my_message_status.dart';
import 'package:talk_it_out/features/groups/data/published_message.dart';

class GroupsNotifier extends AsyncNotifier<List<Group>> {
  @override
  Future<List<Group>> build() async {
    refreshOnLiveEvents(
      ref,
      (e) => e.type == 'groups',
      refresh: ref.invalidateSelf,
    );
    final page = await ref.watch(groupRepositoryProvider).listGroups();
    return page.items;
  }
}

final groupsProvider = AsyncNotifierProvider<GroupsNotifier, List<Group>>(
  GroupsNotifier.new,
);

class GroupDetailNotifier extends AsyncNotifier<Group> {
  GroupDetailNotifier(this.groupId);

  final String groupId;

  @override
  Future<Group> build() {
    refreshOnLiveEvents(
      ref,
      (e) =>
          (e.type == 'members' || e.type == 'review') && e.groupId == groupId,
      refresh: ref.invalidateSelf,
    );
    return ref.watch(groupRepositoryProvider).getGroup(groupId);
  }
}

final groupDetailProvider =
    AsyncNotifierProvider.family<GroupDetailNotifier, Group, String>(
      GroupDetailNotifier.new,
    );

class GroupMessagesNotifier extends AsyncNotifier<List<PublishedMessage>> {
  GroupMessagesNotifier(this.groupId);

  final String groupId;

  @override
  Future<List<PublishedMessage>> build() async {
    refreshOnLiveEvents(
      ref,
      (e) => e.type == 'chat' && e.groupId == groupId,
      refresh: ref.invalidateSelf,
    );
    final page = await ref.watch(groupRepositoryProvider).listMessages(groupId);
    return page.items;
  }
}

final groupMessagesProvider =
    AsyncNotifierProvider.family<
      GroupMessagesNotifier,
      List<PublishedMessage>,
      String
    >(GroupMessagesNotifier.new);

class MyMessagesNotifier extends AsyncNotifier<List<MyMessageStatus>> {
  MyMessagesNotifier(this.groupId);

  final String groupId;

  @override
  Future<List<MyMessageStatus>> build() async {
    refreshOnLiveEvents(
      ref,
      (e) => e.type == 'mine' && e.groupId == groupId,
      refresh: ref.invalidateSelf,
    );
    final page = await ref
        .watch(groupRepositoryProvider)
        .listMyMessages(groupId);
    return page.items;
  }
}

final myMessagesProvider =
    AsyncNotifierProvider.family<
      MyMessagesNotifier,
      List<MyMessageStatus>,
      String
    >(MyMessagesNotifier.new);

class MembersNotifier extends AsyncNotifier<List<GroupMember>> {
  MembersNotifier(this.groupId);

  final String groupId;

  @override
  Future<List<GroupMember>> build() async {
    refreshOnLiveEvents(
      ref,
      (e) => e.type == 'members' && e.groupId == groupId,
      refresh: ref.invalidateSelf,
    );
    final page = await ref.watch(groupRepositoryProvider).listMembers(groupId);
    return page.items;
  }
}

final membersProvider =
    AsyncNotifierProvider.family<MembersNotifier, List<GroupMember>, String>(
      MembersNotifier.new,
    );

/// When the signed-in user last opened each group chat.
///
/// There is no unread field on [Group]. Published messages newer than this
/// time are the unread count. The map lives for the app session.
class GroupReadNotifier extends Notifier<Map<String, DateTime>> {
  @override
  Map<String, DateTime> build() => const {};

  void markOpened(String groupId, {required DateTime at}) {
    final current = state[groupId];
    if (current != null && !at.isAfter(current)) return;
    state = {...state, groupId: at};
  }
}

final groupReadProvider =
    NotifierProvider<GroupReadNotifier, Map<String, DateTime>>(
      GroupReadNotifier.new,
    );

final groupUnreadCountProvider = Provider.family<int, String>((ref, groupId) {
  final messages = ref.watch(groupMessagesProvider(groupId)).value;
  final openedAt = ref.watch(groupReadProvider)[groupId];
  return unreadPublishedCount(messages, openedAt);
});

final groupsUnreadTotalProvider = Provider<int>((ref) {
  final groups = ref.watch(groupsProvider).value ?? const <Group>[];
  var total = 0;
  for (final group in groups) {
    total += ref.watch(groupUnreadCountProvider(group.id));
  }
  return total;
});

int unreadPublishedCount(List<PublishedMessage>? messages, DateTime? openedAt) {
  if (messages == null || messages.isEmpty) return 0;
  if (openedAt == null) return messages.length;
  var count = 0;
  for (final message in messages) {
    if (message.publishedAt.isAfter(openedAt)) count += 1;
  }
  return count;
}

/// Visible badge text. Counts of 1–4 stay as written. Anything higher is "4+".
String unreadBadgeLabel(int count) {
  if (count > 4) return '4+';
  return '$count';
}

/// Reactions for the published messages seen this session, keyed by message
/// id. Loaded from and saved through [GroupRepository].
class MessageReactionsState {
  const MessageReactionsState([this.byMessage = const {}]);

  final Map<String, MessageReactions> byMessage;

  Map<String, int> getCounts(String messageId) =>
      byMessage[messageId]?.counts ?? const {};

  bool hasReacted(String messageId, String emoji) =>
      byMessage[messageId]?.mine.contains(emoji) ?? false;
}

class MessageReactionsNotifier extends Notifier<MessageReactionsState> {
  final Set<String> _requested = {};
  final Map<String, String> _groupOf = {};

  @override
  MessageReactionsState build() {
    // A different account must not inherit the previous user's reactions.
    ref.watch(sessionProvider.select((session) => session.value?.id));
    ref.watch(groupRepositoryProvider);
    _requested.clear();
    _groupOf.clear();
    // Live: someone reacted to a message on screen, or the stream was down.
    final sub = ref.read(realtimeClientProvider).events.listen((event) {
      if (event.isResync) {
        for (final entry in [..._groupOf.entries]) {
          refresh(entry.value, entry.key);
        }
      } else if (event.type == 'reaction' &&
          event.messageId != null &&
          _groupOf.containsKey(event.messageId)) {
        refresh(_groupOf[event.messageId]!, event.messageId!);
      }
    });
    ref.onDispose(sub.cancel);
    return const MessageReactionsState();
  }

  /// Reloads a message's reactions even if already loaded.
  Future<void> refresh(String groupId, String messageId) async {
    _requested.remove(messageId);
    await load(groupId, messageId);
  }

  void _put(MessageReactions reactions) {
    state = MessageReactionsState({
      ...state.byMessage,
      reactions.messageId: reactions,
    });
  }

  /// Fetches a message's reactions once. Failures are silent: reactions are
  /// decoration and must never block reading the chat.
  Future<void> load(String groupId, String messageId) async {
    _groupOf[messageId] = groupId;
    if (!_requested.add(messageId)) return;
    try {
      final loaded = await ref
          .read(groupRepositoryProvider)
          .getReactions(groupId, messageId);
      if (!ref.mounted) return;
      _put(
        MessageReactions(
          messageId: messageId,
          counts: loaded.counts,
          mine: loaded.mine,
        ),
      );
    } catch (_) {
      _requested.remove(messageId);
    }
  }

  /// Toggles immediately, then confirms with the repository. A failed call
  /// restores the previous counts and rethrows.
  Future<void> toggleReaction(
    String groupId,
    String messageId,
    String emoji,
  ) async {
    final before =
        state.byMessage[messageId] ?? MessageReactions(messageId: messageId);
    _put(before.toggled(emoji));
    try {
      final saved = await ref
          .read(groupRepositoryProvider)
          .toggleReaction(groupId, messageId, emoji: emoji);
      if (!ref.mounted) return;
      _put(
        MessageReactions(
          messageId: messageId,
          counts: saved.counts,
          mine: saved.mine,
        ),
      );
    } catch (_) {
      if (ref.mounted) _put(before);
      rethrow;
    }
  }
}

final messageReactionsProvider =
    NotifierProvider<MessageReactionsNotifier, MessageReactionsState>(
      MessageReactionsNotifier.new,
    );
