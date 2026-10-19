import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/models/group.dart';
import 'package:talk_it_out/core/models/group_member.dart';
import 'package:talk_it_out/features/groups/data/my_message_status.dart';
import 'package:talk_it_out/features/groups/data/published_message.dart';

class GroupsNotifier extends AsyncNotifier<List<Group>> {
  @override
  Future<List<Group>> build() async {
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

/// Emoji reactions state for published messages (WhatsApp & Instagram style).
class MessageReactionsState {
  const MessageReactionsState({
    this.counts = const {},
    this.userReactions = const {},
  });

  /// Map of messageId -> Map of emoji -> count
  final Map<String, Map<String, int>> counts;

  /// Map of messageId -> Set of emojis reacted by current user
  final Map<String, Set<String>> userReactions;

  Map<String, int> getCounts(String messageId) => counts[messageId] ?? const {};

  bool hasReacted(String messageId, String emoji) =>
      userReactions[messageId]?.contains(emoji) ?? false;
}

class MessageReactionsNotifier extends Notifier<MessageReactionsState> {
  @override
  MessageReactionsState build() {
    return const MessageReactionsState(
      counts: {
        'pm10': {'❤️': 2, '👍': 3},
        'pm11': {'🔥': 4, '👏': 2},
        'pm12': {'💡': 3, '👍': 1},
        'pm13': {'❤️': 2},
      },
      userReactions: {
        'pm10': {'❤️'},
      },
    );
  }

  void toggleReaction(String messageId, String emoji) {
    final currentCounts = Map<String, int>.from(state.getCounts(messageId));
    final currentUserReactions = Set<String>.from(
      state.userReactions[messageId] ?? const <String>{},
    );

    if (currentUserReactions.contains(emoji)) {
      currentUserReactions.remove(emoji);
      final c = (currentCounts[emoji] ?? 1) - 1;
      if (c <= 0) {
        currentCounts.remove(emoji);
      } else {
        currentCounts[emoji] = c;
      }
    } else {
      currentUserReactions.add(emoji);
      currentCounts[emoji] = (currentCounts[emoji] ?? 0) + 1;
    }

    state = MessageReactionsState(
      counts: {...state.counts, messageId: currentCounts},
      userReactions: {...state.userReactions, messageId: currentUserReactions},
    );
  }
}

final messageReactionsProvider =
    NotifierProvider<MessageReactionsNotifier, MessageReactionsState>(
      MessageReactionsNotifier.new,
    );
