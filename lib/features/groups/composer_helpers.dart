import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talk_it_out/core/models/group_member.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/features/auth/session_controller.dart';
import 'package:talk_it_out/features/groups/group_providers.dart';

/// Unsent text per group, so leaving a chat never loses a half-written
/// message (WhatsApp, Slack). Kept in memory for this session only: drafts
/// may be sensitive, so they are never written to storage.
class ChatDraftsNotifier extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => const {};

  void save(String key, String text) {
    final next = {...state};
    if (text.trim().isEmpty) {
      next.remove(key);
    } else {
      next[key] = text;
    }
    state = next;
  }
}

final chatDraftsProvider =
    NotifierProvider<ChatDraftsNotifier, Map<String, String>>(
      ChatDraftsNotifier.new,
    );

/// Restores the draft into [controller] and keeps saving it as you type.
void bindDraft(WidgetRef ref, String key, TextEditingController controller) {
  final saved = ref.read(chatDraftsProvider)[key];
  if (saved != null && controller.text.isEmpty) {
    controller.value = TextEditingValue(
      text: saved,
      selection: TextSelection.collapsed(offset: saved.length),
    );
  }
  controller.addListener(
    () => ref.read(chatDraftsProvider.notifier).save(key, controller.text),
  );
}

/// The "@na" being typed just before the cursor, or null.
({int start, String query})? activeMention(TextEditingValue value) {
  final cursor = value.selection.baseOffset;
  if (cursor < 0 || cursor > value.text.length) return null;
  final before = value.text.substring(0, cursor);
  final at = before.lastIndexOf('@');
  if (at < 0) return null;
  // "@" must start a word, and the name being typed has no line breaks.
  if (at > 0 && !RegExp(r'\s').hasMatch(before[at - 1])) return null;
  final query = before.substring(at + 1);
  if (query.length > 24 || query.contains('\n') || query.startsWith(' ')) {
    return null;
  }
  return (start: at, query: query);
}

/// Members whose name matches the mention being typed (you are left out).
List<GroupMember> mentionMatches(
  List<GroupMember> members,
  String query,
  String? myId,
) {
  final q = query.toLowerCase().trim();
  return [
    for (final m in members)
      if (m.userId != myId &&
          (q.isEmpty ||
              m.name.toLowerCase().startsWith(q) ||
              m.name
                  .toLowerCase()
                  .split(RegExp(r'\s+'))
                  .any((w) => w.startsWith(q))))
        m,
  ].take(5).toList();
}

/// A row of people to @mention, shown above the message box while typing
/// "@" (Slack, WhatsApp). Choosing one inserts "@Full Name ".
class MentionSuggestions extends ConsumerStatefulWidget {
  const MentionSuggestions({
    required this.groupId,
    required this.controller,
    super.key,
  });

  final String groupId;
  final TextEditingController controller;

  @override
  ConsumerState<MentionSuggestions> createState() => _MentionSuggestionsState();
}

class _MentionSuggestionsState extends ConsumerState<MentionSuggestions> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _insert(GroupMember member, ({int start, String query}) mention) {
    final value = widget.controller.value;
    final end = mention.start + 1 + mention.query.length;
    final insert = '@${member.name} ';
    final text = value.text.replaceRange(mention.start, end, insert);
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: mention.start + insert.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mention = activeMention(widget.controller.value);
    if (mention == null) return const SizedBox.shrink();
    final members =
        ref.watch(membersProvider(widget.groupId)).value ??
        const <GroupMember>[];
    final me = ref.watch(sessionProvider).value?.id;
    final matches = mentionMatches(members, mention.query, me);
    if (matches.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SingleChildScrollView(
        key: const ValueKey('mention-suggestions'),
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final m in matches)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ActionChip(
                  key: ValueKey('mention-${m.userId}'),
                  avatar: CircleAvatar(
                    backgroundColor: Brand.ink,
                    child: Text(
                      m.name.isEmpty ? '?' : m.name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                  label: Text(m.name),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Brand.border),
                  onPressed: () => _insert(m, mention),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
