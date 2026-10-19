import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/models/enums.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/core/ui/labels.dart';
import 'package:talk_it_out/core/ui/screen_async.dart';
import 'package:talk_it_out/core/ui/stitch_chrome.dart';
import 'package:talk_it_out/core/widgets/async_body.dart';
import 'package:talk_it_out/features/groups/data/my_message_status.dart';
import 'package:talk_it_out/features/groups/data/published_message.dart';
import 'package:talk_it_out/features/groups/group_providers.dart';
import 'package:talk_it_out/features/profile/profile_state.dart';

class GroupChatScreen extends ConsumerStatefulWidget {
  const GroupChatScreen({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen> {
  PublishedMessage? _replyingTo;

  void _setReplyingTo(PublishedMessage message) {
    setState(() => _replyingTo = message);
  }

  void _clearReply() {
    setState(() => _replyingTo = null);
  }

  Future<void> _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Group?'),
        content: const Text(
          'Are you sure you want to leave this deliberation? You will no longer receive updates or be able to contribute.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave Group'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(groupRepositoryProvider).leaveGroup(widget.groupId);
      ref.invalidate(groupsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You left the group.'),
            backgroundColor: Color(0xFF09090B),
          ),
        );
        context.go('/groups');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(groupDetailProvider(widget.groupId));
    final userProfile = ref.watch(userProfileProvider);
    final messages = ref.watch(groupMessagesProvider(widget.groupId));
    final items = messages.value ?? const <PublishedMessage>[];
    final isController = group.value?.myRole == GroupRole.controller;

    final members = ref.watch(membersProvider(widget.groupId)).value?.length;
    final mine = ref.watch(myMessagesProvider(widget.groupId)).value;
    final pendingMine = isController
        ? const <MyMessageStatus>[]
        : (mine ?? const <MyMessageStatus>[])
              .where((item) => item.status == MessageStatus.pending)
              .toList();
    DateTime? waitingSince;
    for (final item in pendingMine) {
      final since = waitingSince;
      if (since == null || item.createdAt.isBefore(since)) {
        waitingSince = item.createdAt;
      }
    }
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 900;
    final isMobile = screenWidth < 600;
    final hPad = isDesktop ? (screenWidth - 860) / 2 : (isMobile ? 12.0 : 20.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF09090B) : Colors.white,
      appBar: StitchPageHeader(
        title: 'Active Session',
        emphasizePageTitle: true,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Session options',
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'members') {
                context.push('/groups/${widget.groupId}/members');
              } else if (value == 'invite') {
                context.push('/groups/${widget.groupId}/members');
              } else if (value == 'mine') {
                context.push('/groups/${widget.groupId}/mine');
              } else if (value == 'leave') {
                _leaveGroup();
              } else if (value == 'shield') {
                showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 20,
                          color: Color(0xFF09090B),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Peer Anonymity Shield',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    content: const Text(
                      'Zero-Knowledge Identity Decoupling is active.\n\nAnonymous submissions are mathematically shielded from peers and signed with ephemeral blinded keys. Controllers only see the neutral rephrase proposal.',
                      style: TextStyle(fontSize: 13, height: 1.4),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Understood'),
                      ),
                    ],
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'members',
                child: Text(AppStrings.membersTitle),
              ),
              if (isController)
                const PopupMenuItem(
                  value: 'invite',
                  child: Row(
                    children: [
                      Icon(Icons.person_add_alt_1, size: 16),
                      SizedBox(width: 8),
                      Text('Invite member by username'),
                    ],
                  ),
                ),
              PopupMenuItem(value: 'mine', child: Text(AppStrings.myMessages)),
              const PopupMenuItem(
                value: 'shield',
                child: Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: Color(0xFF71717A),
                    ),
                    SizedBox(width: 8),
                    Text('Safety Shield Info'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'leave',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 16, color: Colors.redAccent),
                    SizedBox(width: 8),
                    Text(
                      'Leave Group',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isController)
            IconButton(
              tooltip: AppStrings.reviewTitle,
              onPressed: () => context.push('/groups/${widget.groupId}/review'),
              icon: const Icon(Icons.fact_check_outlined),
            ),
          Material(
            color: Colors.black,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => context.go('/profile'),
              child: SizedBox(
                width: 32,
                height: 32,
                child: userProfile.avatarUrl != null
                    ? Image.network(
                        userProfile.avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.person,
                              size: 18,
                              color: Colors.white,
                            ),
                      )
                    : const Icon(Icons.person, size: 18, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF09090B) : Colors.white,
        ),
        child: Column(
          children: [
            _MarkGroupOpened(groupId: widget.groupId),
            if (group.value != null)
              Padding(
                padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 0),
                child: _SessionBanner(
                  agenda: group.value!.agenda,
                  role: roleLabel(group.value!.myRole),
                  memberCount: members,
                  onMembers: () =>
                      context.push('/groups/${widget.groupId}/members'),
                  onMine: () => context.push('/groups/${widget.groupId}/mine'),
                  waitingSince: waitingSince,
                ),
              ),
            if (group.value != null)
              Padding(
                padding: EdgeInsets.fromLTRB(hPad, 6, hPad, 0),
                child: _AgendaAnchorPin(agenda: group.value!.agenda),
              ),
            Expanded(
              child: AsyncBody(
                status: asyncStatus(
                  messages,
                  isEmpty: items.isEmpty && pendingMine.isEmpty,
                ),
                errorMessage: errorText(messages.error),
                onRetry: () =>
                    ref.invalidate(groupMessagesProvider(widget.groupId)),
                empty: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.forum_outlined,
                            size: 32,
                            color: Color(0xFF09090B),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No messages yet. Start the conversation.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF71717A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                child: ListView.builder(
                  padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 16),
                  itemCount:
                      items.length +
                      pendingMine.length +
                      (pendingMine.isNotEmpty ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < items.length) {
                      return PublishedMessageTile(
                        message: items[index],
                        groupId: widget.groupId,
                        isController: isController,
                        onReply: () => _setReplyingTo(items[index]),
                      );
                    }
                    final pendingIndex = index - items.length;
                    if (pendingIndex < pendingMine.length) {
                      return _PendingSubmission(
                        item: pendingMine[pendingIndex],
                      );
                    }
                    return const _ReviewingPulsePill();
                  },
                ),
              ),
            ),
            if (group.value != null)
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE4E4E7))),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? hPad : (isMobile ? 0 : 8.0),
                ),
                child: isController
                    ? _ControllerMessageComposer(
                        groupId: widget.groupId,
                        replyingTo: _replyingTo,
                        onClearReply: _clearReply,
                      )
                    : MessageComposer(
                        groupId: widget.groupId,
                        replyingTo: _replyingTo,
                        onClearReply: _clearReply,
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Agenda anchor pin ────────────────────────────────────────────────────────

class _AgendaAnchorPin extends StatelessWidget {
  const _AgendaAnchorPin({required this.agenda});

  final String agenda;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4E4E7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.push_pin_outlined,
            size: 16,
            color: Color(0xFF09090B),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Agenda: $agenda',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF09090B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Published message tile (WhatsApp Style) ──────────────────────────────────

class PublishedMessageTile extends ConsumerStatefulWidget {
  const PublishedMessageTile({
    required this.message,
    this.groupId = '',
    this.isController = false,
    this.onReply,
    super.key,
  });

  final PublishedMessage message;
  final String groupId;
  final bool isController;
  final VoidCallback? onReply;

  @override
  ConsumerState<PublishedMessageTile> createState() =>
      _PublishedMessageTileState();
}

class _PublishedMessageTileState extends ConsumerState<PublishedMessageTile> {
  bool _showReactionsBar = false;

  void _toggleReactionsBar() {
    setState(() => _showReactionsBar = !_showReactionsBar);
  }

  void _reactWith(String emoji) {
    ref
        .read(messageReactionsProvider.notifier)
        .toggleReaction(widget.message.id, emoji);
    setState(() => _showReactionsBar = false);
  }

  void _showAllEmojis() {
    setState(() => _showReactionsBar = false);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'React with Emoji',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF09090B),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final emoji in [
                    '❤️',
                    '👍',
                    '🔥',
                    '😂',
                    '👏',
                    '🎉',
                    '🙌',
                    '💯',
                    '🚀',
                    '🤔',
                    '💡',
                    '🙏',
                    '✨',
                    '👀',
                    '🤝',
                    '🧠',
                    '⚡',
                    '🎯',
                    '📌',
                    '💬',
                    '☕',
                    '🌟',
                    '🦾',
                    '😍',
                  ])
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _reactWith(emoji);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F4F5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _authorColor(String name) {
    if (name.contains('Anonymous')) return const Color(0xFF71717A);
    final hash = name.codeUnits.fold(0, (acc, c) => acc + c);
    const colors = [
      Color(0xFF09090B),
      Color(0xFF27272A),
      Color(0xFF3F3F46),
      Color(0xFF52525B),
      Color(0xFF18181B),
    ];
    return colors[hash % colors.length];
  }

  Future<void> _deleteMessage() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Message?'),
        content: const Text(
          'This will permanently delete this published message from the group chat for all participants.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref
          .read(groupRepositoryProvider)
          .deleteMessage(widget.groupId, widget.message.id);
      ref.invalidate(groupMessagesProvider(widget.groupId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message deleted by Controller.'),
            backgroundColor: Color(0xFF09090B),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAnonymous = widget.message.displaySender == null;
    final senderName =
        widget.message.displaySender?.name ?? AppStrings.anonymousUser;
    final isMe =
        widget.message.displaySender?.id == 'u1' ||
        widget.message.displaySender?.name == 'Priya';
    final isOfficialController =
        widget.message.displaySender?.name.contains('Controller') ?? false;

    // Parse potential reply quote
    String? quoteSender;
    String? quoteSnippet;
    String messageBody = widget.message.text;

    if (messageBody.startsWith('> Replying to ')) {
      final lines = messageBody.split('\n\n');
      if (lines.length >= 2) {
        final quoteHeader = lines[0];
        final match = RegExp(r'^> Replying to (.*?):\s*"(.*?)"')
            .firstMatch(quoteHeader);
        if (match != null) {
          quoteSender = match.group(1);
          quoteSnippet = match.group(2);
          messageBody = lines.sublist(1).join('\n\n');
        }
      }
    }

    final authorColor = _authorColor(senderName);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasScope =
        context.findAncestorWidgetOfExactType<ProviderScope>() != null ||
        context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() !=
            null;
    final reactions = hasScope ? ref.watch(messageReactionsProvider) : null;
    final reactionCounts =
        reactions?.getCounts(widget.message.id) ?? const <String, int>{};
    final screenW = MediaQuery.sizeOf(context).width;
    final isNarrow = screenW < 600;
    final bubbleMaxWidth = isNarrow
        ? screenW * 0.84
        : (screenW < 900 ? 540.0 : 640.0);

    return Semantics(
      label: '$senderName. ${widget.message.text}',
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            // Instagram / WhatsApp Floating Emoji Reaction Bar
            if (_showReactionsBar)
              Padding(
                padding: EdgeInsets.only(
                  left: isMe ? 0 : 40,
                  right: isMe ? 8 : 0,
                  bottom: 6,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF18181B) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF27272A)
                          : const Color(0xFFE4E4E7),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x18000000),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final emoji in ['❤️', '👍', '😂', '😮', '😢', '🔥'])
                        InkWell(
                          onTap: () => _reactWith(emoji),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                      InkWell(
                        onTap: _showAllEmojis,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF27272A)
                                : const Color(0xFFF4F4F5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add,
                            size: 16,
                            color: Color(0xFF71717A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            Row(
              mainAxisAlignment: isMe
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isMe) ...[
                  _SenderMark(name: senderName, anonymous: isAnonymous),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Column(
                    crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Container(
                        constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        decoration: BoxDecoration(
                          color: isMe
                              ? (isDark
                                    ? const Color(0xFF18181B)
                                    : const Color(
                                        0xFF09090B,
                                      )) // Monochrome Black
                              : (isDark
                                    ? const Color(0xFF18181B)
                                    : Colors.white), // Monochrome White
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(isMe ? 14 : 3),
                            topRight: Radius.circular(isMe ? 3 : 14),
                            bottomLeft: const Radius.circular(14),
                            bottomRight: const Radius.circular(14),
                          ),
                          border: Border.all(
                            color: isMe
                                ? (isDark
                                      ? const Color(0xFF27272A)
                                      : const Color(0xFF27272A))
                                : const Color(0xFFE4E4E7),
                            width: 0.8,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0C000000),
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header / Author line
                            if (!isMe) ...[
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      senderName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? Colors.white
                                            : authorColor,
                                      ),
                                    ),
                                  ),
                                  if (isAnonymous) ...[
                                    const SizedBox(width: 6),
                                    const _ShieldedChip(),
                                  ],
                                  if (isOfficialController) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF09090B),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'CONTROLLER',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                            ],

                            // Quoted Reply preview inside bubble
                            if (quoteSender != null &&
                                quoteSnippet != null) ...[
                              Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? const Color(0xFF27272A)
                                      : const Color(0xFFF4F4F5),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border(
                                    left: BorderSide(
                                      color: isMe
                                          ? Colors.white
                                          : const Color(0xFF09090B),
                                      width: 3.5,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      quoteSender,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isMe
                                            ? Colors.white
                                            : const Color(0xFF09090B),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      quoteSnippet,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isMe
                                            ? const Color(0xFFA1A1AA)
                                            : const Color(0xFF71717A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Message text
                            Text(
                              messageBody,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: isMe
                                    ? Colors.white
                                    : (isDark
                                          ? Colors.white
                                          : const Color(0xFF09090B)),
                              ),
                            ),
                            const SizedBox(height: 4),

                            // Footer with time, checkmarks, react icon, and popup menu
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (isAnonymous)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Icon(
                                      Icons.verified_user_outlined,
                                      size: 11,
                                      color: isMe
                                          ? const Color(0xFFA1A1AA)
                                          : const Color(0xFF71717A),
                                    ),
                                  ),
                                Text(
                                  _clock(widget.message.publishedAt),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isMe
                                        ? const Color(0xFFA1A1AA)
                                        : const Color(0xFF71717A),
                                  ),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.done_all,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ],
                                const SizedBox(width: 8),

                                // Quick React button
                                IconButton(
                                  icon: const Icon(
                                    Icons.add_reaction_outlined,
                                    size: 14,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  color: isMe
                                      ? const Color(0xFFA1A1AA)
                                      : const Color(0xFF71717A),
                                  tooltip: 'React',
                                  onPressed: _toggleReactionsBar,
                                ),
                                const SizedBox(width: 6),

                                // Action menu on bubble
                                PopupMenuButton<String>(
                                  padding: EdgeInsets.zero,
                                  iconSize: 14,
                                  constraints: const BoxConstraints(),
                                  icon: Icon(
                                    Icons.expand_more,
                                    size: 14,
                                    color: isMe
                                        ? const Color(0xFFA1A1AA)
                                        : const Color(0xFF71717A),
                                  ),
                                  onSelected: (action) {
                                    if (action == 'react') {
                                      _toggleReactionsBar();
                                    } else if (action == 'reply') {
                                      widget.onReply?.call();
                                    } else if (action == 'copy') {
                                      Clipboard.setData(
                                        ClipboardData(
                                          text: widget.message.text,
                                        ),
                                      );
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Message copied to clipboard',
                                              ),
                                              duration: Duration(seconds: 1),
                                            ),
                                          );
                                    } else if (action == 'delete') {
                                      _deleteMessage();
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(
                                      value: 'react',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.add_reaction_outlined,
                                            size: 16,
                                          ),
                                          SizedBox(width: 8),
                                          Text('React with emoji'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'reply',
                                      child: Row(
                                        children: [
                                          Icon(Icons.reply, size: 16),
                                          SizedBox(width: 8),
                                          Text('Reply'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'copy',
                                      child: Row(
                                        children: [
                                          Icon(Icons.copy, size: 16),
                                          SizedBox(width: 8),
                                          Text('Copy text'),
                                        ],
                                      ),
                                    ),
                                    if (widget.isController)
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.delete_outline,
                                              size: 16,
                                              color: Colors.redAccent,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Delete message',
                                              style: TextStyle(
                                                color: Colors.redAccent,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Emoji Reaction Badges (WhatsApp / Instagram style)
                      if (reactionCounts.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (final entry in reactionCounts.entries) ...[
                              Builder(
                                builder: (context) {
                                  final userReacted = reactions?.hasReacted(
                                        widget.message.id,
                                        entry.key,
                                      ) ??
                                      false;
                                  return InkWell(
                                    onTap: () => ref
                                        .read(messageReactionsProvider.notifier)
                                        .toggleReaction(
                                          widget.message.id,
                                          entry.key,
                                        ),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: userReacted
                                            ? (isDark
                                                  ? const Color(0xFF27272A)
                                                  : const Color(0xFF09090B))
                                            : (isDark
                                                  ? const Color(0xFF18181B)
                                                  : const Color(0xFFF4F4F5)),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: userReacted
                                              ? const Color(0xFF09090B)
                                              : const Color(0xFFE4E4E7),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            entry.key,
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            '${entry.value}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: userReacted
                                                  ? Colors.white
                                                  : (isDark
                                                        ? Colors.white70
                                                        : const Color(
                                                            0xFF09090B,
                                                          )),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Controller Message Composer ──────────────────────────────────────────────

class _ControllerMessageComposer extends ConsumerStatefulWidget {
  const _ControllerMessageComposer({
    required this.groupId,
    this.replyingTo,
    this.onClearReply,
  });

  final String groupId;
  final PublishedMessage? replyingTo;
  final VoidCallback? onClearReply;

  @override
  ConsumerState<_ControllerMessageComposer> createState() =>
      _ControllerMessageComposerState();
}

class _ControllerMessageComposerState
    extends ConsumerState<_ControllerMessageComposer> {
  final _text = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _sendControllerNote() async {
    final rawText = _text.text.trim();
    if (rawText.isEmpty) return;

    setState(() => _busy = true);
    try {
      String fullText = rawText;
      if (widget.replyingTo != null) {
        final sender =
            widget.replyingTo!.displaySender?.name ?? 'Anonymous user';
        final snippet = widget.replyingTo!.text.length > 50
            ? '${widget.replyingTo!.text.substring(0, 50)}…'
            : widget.replyingTo!.text;
        fullText = '> Replying to $sender: "$snippet"\n\n$rawText';
      }

      await ref
          .read(groupRepositoryProvider)
          .sendControllerMessage(widget.groupId, text: fullText);
      _text.clear();
      widget.onClearReply?.call();
      ref.invalidate(groupMessagesProvider(widget.groupId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Controller message published to group.'),
            backgroundColor: Color(0xFF09090B),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isMobile ? 10 : 16,
          6,
          isMobile ? 10 : 16,
          isMobile ? 8 : 12,
        ),
        child: Container(
          padding: EdgeInsets.all(isMobile ? 8 : 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE4E4E7)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Quoted reply bar (if active)
              if (widget.replyingTo != null) ...[
                _QuotedReplyBar(
                  replyingTo: widget.replyingTo!,
                  onClear: widget.onClearReply,
                ),
                const SizedBox(height: 8),
              ],

              // Chat Input Row (Message Pill + Black Send Button) - Identical to Contributor
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE4E4E7)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.sentiment_satisfied_alt_outlined,
                              color: Color(0xFF8696A0),
                              size: 22,
                            ),
                            onPressed: () {},
                          ),
                          Expanded(
                            child: TextField(
                              controller: _text,
                              minLines: 1,
                              maxLines: 5,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                hintText: 'Message',
                                hintStyle: TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF8696A0),
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.attach_file_rounded,
                              color: Color(0xFF8696A0),
                              size: 20,
                            ),
                            onPressed: () {},
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF09090B),
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      elevation: 1,
                    ),
                    onPressed: _busy ? null : _sendControllerNote,
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Send',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 5),
                              Icon(Icons.send_rounded, size: 16),
                            ],
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── WhatsApp Quoted Reply Bar ────────────────────────────────────────────────

class _QuotedReplyBar extends StatelessWidget {
  const _QuotedReplyBar({required this.replyingTo, this.onClear});

  final PublishedMessage replyingTo;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final sender = replyingTo.displaySender?.name ?? AppStrings.anonymousUser;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: Color(0xFF09090B), width: 3.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to $sender',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF09090B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  replyingTo.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF71717A),
                  ),
                ),
              ],
            ),
          ),
          if (onClear != null)
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: onClear,
            ),
        ],
      ),
    );
  }
}

// ─── Message composer (Contributor) ───────────────────────────────────────────

class MessageComposer extends ConsumerStatefulWidget {
  const MessageComposer({
    required this.groupId,
    this.replyingTo,
    this.onClearReply,
    super.key,
  });

  final String groupId;
  final PublishedMessage? replyingTo;
  final VoidCallback? onClearReply;

  @override
  ConsumerState<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends ConsumerState<MessageComposer> {
  final _text = TextEditingController();
  var _anonymous = false;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final rawText = _text.text.trim();
    if (rawText.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      String fullText = rawText;
      if (widget.replyingTo != null) {
        final sender =
            widget.replyingTo!.displaySender?.name ?? 'Anonymous user';
        final snippet = widget.replyingTo!.text.length > 50
            ? '${widget.replyingTo!.text.substring(0, 50)}…'
            : widget.replyingTo!.text;
        fullText = '> Replying to $sender: "$snippet"\n\n$rawText';
      }

      await ref
          .read(groupRepositoryProvider)
          .sendMessage(widget.groupId, text: fullText, isAnonymous: _anonymous);
      _text.clear();
      _anonymous = false;
      widget.onClearReply?.call();
      ref.invalidate(myMessagesProvider(widget.groupId));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(AppStrings.statusPending)));
      }
    } on RepositoryException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = AppStrings.errorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isMobile ? 10 : 16,
          6,
          isMobile ? 10 : 16,
          isMobile ? 8 : 12,
        ),
        child: Container(
          padding: EdgeInsets.all(isMobile ? 8 : 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE4E4E7)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Privacy disclosure
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F4F5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF4F4F5)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: Color(0xFF09090B),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Messages undergo AI clarity rephrasing and Controller approval before publishing.',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.3,
                          color: Color(0xFF71717A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // WhatsApp Quoted Reply Bar (if active)
              if (widget.replyingTo != null) ...[
                _QuotedReplyBar(
                  replyingTo: widget.replyingTo!,
                  onClear: widget.onClearReply,
                ),
                const SizedBox(height: 8),
              ],

              // Anonymous Checkbox & Anonymity Disclosure (Sits above input and send)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _anonymous
                      ? const Color(0xFFF4F4F5)
                      : const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _anonymous
                        ? const Color(0xFF09090B)
                        : const Color(0xFFE4E4E7),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: _busy
                          ? null
                          : () => setState(() => _anonymous = !_anonymous),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: Checkbox(
                              value: _anonymous,
                              onChanged: _busy
                                  ? null
                                  : (value) => setState(
                                      () => _anonymous = value ?? false,
                                    ),
                              activeColor: const Color(0xFF09090B),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            AppStrings.anonymousCheckbox,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF09090B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 28, top: 2, right: 4),
                      child: Text(
                        AppStrings.anonymousDisclosure,
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF71717A),
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),

              // Chat Input Row (Message Pill + Black Send Button)
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE4E4E7)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.sentiment_satisfied_alt_outlined,
                              color: Color(0xFF8696A0),
                              size: 22,
                            ),
                            onPressed: () {},
                          ),
                          Expanded(
                            child: TextField(
                              controller: _text,
                              minLines: 1,
                              maxLines: 5,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                hintText: 'Message',
                                hintStyle: TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF8696A0),
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.attach_file_rounded,
                              color: Color(0xFF8696A0),
                              size: 20,
                            ),
                            onPressed: () {},
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF09090B),
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      elevation: 1,
                    ),
                    onPressed: _busy ? null : _send,
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                AppStrings.send,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 5),
                              Icon(Icons.send_rounded, size: 16),
                            ],
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Pending submission card ──────────────────────────────────────────────────

class _PendingSubmission extends StatelessWidget {
  const _PendingSubmission({required this.item});

  final MyMessageStatus item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E4E7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Your submission  \u2022  ${_clock(item.createdAt)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF09090B),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F4F5),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFE4E4E7)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _SpinningIcon(
                                icon: Icons.hourglass_top,
                                size: 11,
                              ),
                              SizedBox(width: 3),
                              Text(
                                'PENDING REVIEW',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                  color: Color(0xFF09090B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE4E4E7)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.auto_fix_high,
                                size: 13,
                                color: Color(0xFF09090B),
                              ),
                              SizedBox(width: 5),
                              Text(
                                'AI Synthesizing Non-Adversarial Phrasing…',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF71717A),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Controller reviewing pulse pill ─────────────────────────────────────────

class _ReviewingPulsePill extends StatelessWidget {
  const _ReviewingPulsePill();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE4E4E7)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PingDot(),
            SizedBox(width: 6),
            Text(
              'Controller is reviewing submissions in real-time',
              style: TextStyle(fontSize: 11, color: Color(0xFF71717A)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PingDot extends StatelessWidget {
  const _PingDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _SpinningIcon extends StatelessWidget {
  const _SpinningIcon({required this.icon, required this.size});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: size, color: const Color(0xFF09090B));
  }
}

// ─── Session banner ───────────────────────────────────────────────────────────

class _SessionBanner extends StatelessWidget {
  const _SessionBanner({
    required this.agenda,
    required this.role,
    required this.memberCount,
    required this.onMembers,
    required this.onMine,
    required this.waitingSince,
  });

  final String agenda;
  final String role;
  final int? memberCount;
  final VoidCallback onMembers;
  final VoidCallback onMine;
  final DateTime? waitingSince;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isNarrow = screenWidth < 460;
    final memberStr = memberCount == null
        ? '\u2014'
        : '$memberCount ${memberCount == 1 ? 'member' : 'members'}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E4E7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agenda,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF09090B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            role.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          '\u2022',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFFA1A1AA),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          memberStr,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF71717A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isNarrow) ...[
                const SizedBox(width: 8),
                _BannerButton(
                  tooltip: AppStrings.membersTitle,
                  icon: Icons.group_outlined,
                  label: memberCount?.toString() ?? '\u2014',
                  onTap: onMembers,
                ),
                const SizedBox(width: 6),
                _BannerButton(
                  tooltip: AppStrings.myMessages,
                  icon: Icons.bookmark_border,
                  label: 'Mine',
                  onTap: onMine,
                ),
              ],
            ],
          ),
          if (isNarrow) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _BannerButton(
                  tooltip: AppStrings.membersTitle,
                  icon: Icons.group_outlined,
                  label: memberCount?.toString() ?? '\u2014',
                  onTap: onMembers,
                ),
                const SizedBox(width: 6),
                _BannerButton(
                  tooltip: AppStrings.myMessages,
                  icon: Icons.bookmark_border,
                  label: 'Mine',
                  onTap: onMine,
                ),
              ],
            ),
          ],
          if (waitingSince != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE4E4E7)),
              ),
              child: Row(
                children: [
                  const _PingDot(),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Waiting for controller review',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF71717A),
                      ),
                    ),
                  ),
                  Text(
                    _clock(waitingSince!),
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFFA1A1AA),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BannerButton extends StatelessWidget {
  const _BannerButton({
    required this.tooltip,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE4E4E7)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: const Color(0xFF09090B)),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF09090B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sender avatar ────────────────────────────────────────────────────────────

class _SenderMark extends StatelessWidget {
  const _SenderMark({required this.name, required this.anonymous});

  final String name;
  final bool anonymous;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: anonymous ? const Color(0xFFF4F4F5) : Colors.black,
        shape: BoxShape.circle,
        border: Border.all(
          color: anonymous ? const Color(0xFFE4E4E7) : Colors.black,
        ),
      ),
      child: anonymous
          ? const Icon(
              Icons.visibility_off_outlined,
              size: 14,
              color: Color(0xFF09090B),
            )
          : Text(
              _initials(name),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}

// ─── Shielded chip ───────────────────────────────────────────────────────────

class _ShieldedChip extends StatelessWidget {
  const _ShieldedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE4E4E7)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 10, color: Color(0xFF09090B)),
          SizedBox(width: 2),
          Text(
            'Shielded',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF71717A),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Mark group opened ────────────────────────────────────────────────────────

class _MarkGroupOpened extends ConsumerStatefulWidget {
  const _MarkGroupOpened({required this.groupId});

  final String groupId;

  @override
  ConsumerState<_MarkGroupOpened> createState() => _MarkGroupOpenedState();
}

class _MarkGroupOpenedState extends ConsumerState<_MarkGroupOpened> {
  DateTime? _marked;

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(groupMessagesProvider(widget.groupId)).value;
    if (messages != null) {
      final openedAt = messages.isEmpty
          ? DateTime.now().toUtc()
          : messages
                .map((message) => message.publishedAt)
                .reduce((latest, time) => latest.isAfter(time) ? latest : time);
      final marked = _marked;
      if (marked == null || openedAt.isAfter(marked)) {
        _marked = openedAt;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref
              .read(groupReadProvider.notifier)
              .markOpened(widget.groupId, at: openedAt);
        });
      }
    }
    return const SizedBox.shrink();
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final word = parts.first;
    return word.length == 1
        ? word.toUpperCase()
        : word.substring(0, 2).toUpperCase();
  }
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

String _clock(DateTime value) {
  final local = value.toLocal();
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '$hour12:$minute $suffix';
}
