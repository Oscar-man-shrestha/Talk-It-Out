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
import 'package:talk_it_out/features/auth/session_controller.dart';
import 'package:talk_it_out/features/groups/data/message_reactions.dart';
import 'package:talk_it_out/features/groups/data/my_message_status.dart';
import 'package:talk_it_out/features/groups/data/published_message.dart';
import 'package:talk_it_out/features/groups/group_providers.dart';
import 'package:talk_it_out/features/profile/profile_state.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/features/groups/chat_image.dart';
import 'package:talk_it_out/features/groups/chat_extras.dart';

class GroupChatScreen extends ConsumerStatefulWidget {
  const GroupChatScreen({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen> {
  PublishedMessage? _replyingTo;
  final _keys = <String, GlobalKey>{};

  GlobalKey _keyFor(String id) => _keys.putIfAbsent(id, GlobalKey.new);

  /// Scrolls to a loaded message and flashes nothing; says so if it is
  /// further back than what is loaded.
  void _scrollTo(String messageId) {
    final ctx = _keys[messageId]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        alignment: 0.3,
        curve: Curves.easeOut,
      );
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(AppStrings.olderMessageHint)));
  }

  Future<void> _openSearch() async {
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Brand.card,
      builder: (_) => ChatSearchSheet(groupId: widget.groupId),
    );
    if (id != null && mounted) _scrollTo(id);
  }

  void _setReplyingTo(PublishedMessage message) {
    setState(() => _replyingTo = message);
  }

  void _clearReply() {
    setState(() => _replyingTo = null);
  }

  Future<void> _leaveGroup() async {
    final isController =
        ref.read(groupDetailProvider(widget.groupId)).value?.myRole ==
        GroupRole.controller;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Group?'),
        content: Text(
          isController
              ? 'Are you sure you want to leave this deliberation? You will no longer receive updates or be able to contribute. The member who joined earliest will become the controller.'
              : 'Are you sure you want to leave this deliberation? You will no longer receive updates or be able to contribute.',
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
      try {
        await ref.read(groupRepositoryProvider).leaveGroup(widget.groupId);
      } on RepositoryException catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error.message)));
        }
        return;
      }
      ref.invalidate(groupsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You left the group.'),
            backgroundColor: Brand.ink,
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
    final currentUserId = ref.watch(sessionProvider).value?.id;
    final controllerId = group.value?.controllerId;

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
      backgroundColor: isDark ? Brand.ink : Brand.canvas,
      appBar: StitchPageHeader(
        title: group.value?.agenda ?? AppStrings.groupChatTitle,
        emphasizePageTitle: true,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
        actions: [
          IconButton(
            key: const ValueKey('chat-search'),
            tooltip: AppStrings.searchHint,
            icon: const Icon(Icons.search),
            onPressed: _openSearch,
          ),
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
                        Icon(Icons.shield_outlined, size: 20, color: Brand.ink),
                        SizedBox(width: 8),
                        Text(
                          'Peer Anonymity Shield',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    content: const Text(
                      'Anonymous messages are hidden from the group but visible to the controller.\n\nEvery message is rewritten for tone, then the controller reviews the original next to the rewrite and decides whether to publish it. Other members never see your original wording.',
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
                    Icon(Icons.shield_outlined, size: 16, color: Brand.inkSoft),
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
            color: Brand.accent,
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
        decoration: BoxDecoration(color: isDark ? Brand.ink : Colors.white),
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
            if (items.any((m) => m.pinned))
              Padding(
                padding: EdgeInsets.fromLTRB(hPad, 6, hPad, 0),
                child: PinnedBar(
                  message: items.lastWhere((m) => m.pinned),
                  onTap: _scrollTo,
                ),
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
                            color: Brand.ink,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No messages yet. Start the conversation.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Brand.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Starts at the newest message; every loaded message is
                // built so a reply quote or search result can jump to it.
                child: SingleChildScrollView(
                  key: const ValueKey('chat-scroll'),
                  reverse: true,
                  padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (ref
                          .watch(groupMessagesProvider(widget.groupId).notifier)
                          .hasEarlier)
                        Center(
                          child: TextButton.icon(
                            key: const ValueKey('load-earlier'),
                            onPressed: () => ref
                                .read(
                                  groupMessagesProvider(widget.groupId)
                                      .notifier,
                                )
                                .loadEarlier(),
                            icon: const Icon(Icons.history, size: 16),
                            label: const Text(AppStrings.loadEarlier),
                          ),
                        ),
                      for (final m in items)
                        KeyedSubtree(
                          key: _keyFor(m.id),
                          child: PublishedMessageTile(
                            message: m,
                            groupId: widget.groupId,
                            isController: isController,
                            currentUserId: currentUserId,
                            controllerId: controllerId,
                            onReply: () => _setReplyingTo(m),
                            onQuoteTap: _scrollTo,
                          ),
                        ),
                      for (final p in pendingMine)
                        _PendingWithWithdraw(item: p),
                      if (pendingMine.isNotEmpty) const _ReviewingPulsePill(),
                    ],
                  ),
                ),
              ),
            ),
            if (group.value != null)
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Brand.border)),
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
        border: Border.all(color: Brand.border),
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
          const Icon(Icons.push_pin_outlined, size: 16, color: Brand.ink),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Agenda: $agenda',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Brand.ink,
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
    this.currentUserId,
    this.controllerId,
    this.onReply,
    this.onQuoteTap,
    super.key,
  });

  /// Jumps to the message a reply quotes.
  final ValueChanged<String>? onQuoteTap;

  final PublishedMessage message;
  final String groupId;
  final bool isController;

  /// The signed-in user: their own messages sit on the right.
  final String? currentUserId;

  /// The group's controller: their messages carry the Controller badge.
  final String? controllerId;
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_hasProviderScope) return;
      ref
          .read(messageReactionsProvider.notifier)
          .load(widget.message.groupId, widget.message.id);
    });
  }

  /// The tile is also rendered on its own in widget tests, with no providers.
  bool get _hasProviderScope =>
      context.findAncestorWidgetOfExactType<ProviderScope>() != null ||
      context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() !=
          null;

  Future<void> _toggleReaction(String emoji) async {
    try {
      await ref
          .read(messageReactionsProvider.notifier)
          .toggleReaction(widget.message.groupId, widget.message.id, emoji);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorText(error) ?? AppStrings.errorGeneric)),
      );
    }
  }

  void _reactWith(String emoji) {
    _toggleReaction(emoji);
    setState(() => _showReactionsBar = false);
  }

  void _showAllEmojis() {
    setState(() => _showReactionsBar = false);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Brand.canvas,
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
                      color: Brand.ink,
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
                  for (final emoji in kReactionEmojis)
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _reactWith(emoji);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Brand.muted,
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
    if (name.contains('Anonymous')) return Brand.inkSoft;
    final hash = name.codeUnits.fold(0, (acc, c) => acc + c);
    const colors = [
      Brand.ink,
      Color(0xFF27272A),
      Color(0xFF3F3F46),
      Color(0xFF52525B),
      Color(0xFF18181B),
    ];
    return colors[hash % colors.length];
  }

  Future<void> _togglePin() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(groupRepositoryProvider)
          .setPinned(
            widget.groupId,
            widget.message.id,
            pinned: !widget.message.pinned,
          );
      ref.invalidate(groupMessagesProvider(widget.groupId));
    } on RepositoryException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
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
            backgroundColor: Brand.ink,
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
    // Decided by id, never by name: anyone can be called "Priya".
    final senderId = widget.message.displaySender?.id;
    final isMe = senderId != null && senderId == widget.currentUserId;
    final isOfficialController =
        senderId != null && senderId == widget.controllerId;

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
    // Real replies (API.md 50) carry the quote as data.
    final reply = widget.message.replyTo;
    if (reply != null) {
      quoteSender = reply.displaySender?.name ?? AppStrings.anonymousUser;
      quoteSnippet = reply.text;
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
                      color: isDark ? const Color(0xFF27272A) : Brand.border,
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
                      for (final emoji in kReactionEmojis)
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
                                : Brand.muted,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add,
                            size: 16,
                            color: Brand.inkSoft,
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
                                    ? const Color(0xFF27272A)
                                    : Brand.accent) // Your messages: indigo
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
                                : Brand.border,
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
                                        color: Brand.ink,
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
                              GestureDetector(
                                key: ValueKey('quote-${widget.message.id}'),
                                onTap: reply == null
                                    ? null
                                    : () => widget.onQuoteTap?.call(reply.id),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? Colors.white.withValues(alpha: 0.16)
                                        : Brand.muted,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border(
                                      left: BorderSide(
                                        color: isMe ? Colors.white : Brand.ink,
                                        width: 3.5,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        quoteSender,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isMe
                                              ? Colors.white
                                              : Brand.ink,
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
                                              ? Brand.accentSoft
                                              : Brand.inkSoft,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],

                            if (widget.message.attachmentId != null) ...[
                              ChatImage(
                                groupId: widget.groupId,
                                attachmentId: widget.message.attachmentId!,
                              ),
                              const SizedBox(height: 6),
                            ],

                            // Message text
                            Text(
                              messageBody,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: isMe
                                    ? Colors.white
                                    : (isDark ? Colors.white : Brand.ink),
                              ),
                            ),
                            if (widget.message.poll != null) ...[
                              const SizedBox(height: 8),
                              PollCard(
                                groupId: widget.groupId,
                                poll: widget.message.poll!,
                                onDark: isMe,
                              ),
                            ],
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
                                          ? Brand.accentBorder
                                          : Brand.inkSoft,
                                    ),
                                  ),
                                Text(
                                  _clock(widget.message.publishedAt),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isMe
                                        ? Brand.accentBorder
                                        : Brand.inkSoft,
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
                                      ? Brand.accentBorder
                                      : Brand.inkSoft,
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
                                        ? Brand.accentBorder
                                        : Brand.inkSoft,
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
                                    } else if (action == 'pin') {
                                      _togglePin();
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
                                      PopupMenuItem(
                                        value: 'pin',
                                        child: Row(
                                          children: [
                                            Icon(
                                              widget.message.pinned
                                                  ? Icons.push_pin
                                                  : Icons.push_pin_outlined,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              widget.message.pinned
                                                  ? AppStrings.unpin
                                                  : AppStrings.pin,
                                            ),
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
                                  final userReacted =
                                      reactions?.hasReacted(
                                        widget.message.id,
                                        entry.key,
                                      ) ??
                                      false;
                                  return InkWell(
                                    onTap: () => _toggleReaction(entry.key),
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
                                                  : Brand.accent)
                                            : (isDark
                                                  ? const Color(0xFF18181B)
                                                  : Brand.muted),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: userReacted
                                              ? Brand.accent
                                              : Brand.border,
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
                                                        : Brand.ink),
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
  PickedImage? _image;

  Future<void> _pickImage() async {
    try {
      final picked = await pickChatImage();
      if (picked != null && mounted) setState(() => _image = picked);
    } on RepositoryException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _sendControllerNote() async {
    final rawText = _text.text.trim();
    if (rawText.isEmpty) {
      if (_image != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.imageCaptionNeeded)),
        );
      }
      return;
    }

    setState(() => _busy = true);
    try {
      // Replies are sent as a link to the message (API.md 50), not pasted
      // into the text, so the AI only rewrites what the sender wrote.
      final fullText = rawText;
      final replyToId = widget.replyingTo?.id;

      final repo = ref.read(groupRepositoryProvider);
      final image = _image;
      final attachmentId = image == null
          ? null
          : await repo.uploadAttachment(
              widget.groupId,
              bytes: image.bytes,
              filename: image.filename,
            );
      await repo.sendControllerMessage(
        widget.groupId,
        text: fullText,
        attachmentId: attachmentId,
        replyToId: replyToId,
      );
      _text.clear();
      _image = null;
      widget.onClearReply?.call();
      ref.invalidate(groupMessagesProvider(widget.groupId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Controller message published to group.'),
            backgroundColor: Brand.ink,
          ),
        );
      }
    } on RepositoryException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(AppStrings.errorGeneric)));
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
            border: Border.all(color: Brand.border),
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

              if (_image != null) ...[
                PendingImagePreview(
                  image: _image!,
                  anonymous: false,
                  onRemove: _busy ? null : () => setState(() => _image = null),
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
                        border: Border.all(color: Brand.border),
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
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 34,
                              minHeight: 40,
                            ),
                            icon: const Icon(
                              Icons.sentiment_satisfied_alt_outlined,
                              color: Color(0xFF8696A0),
                              size: 22,
                            ),
                            tooltip: AppStrings.emojiTooltip,
                            onPressed: () => showEmojiPicker(context, _text),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _text,
                              minLines: 1,
                              maxLines: 5,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                hintText: 'Message',
                                filled: false,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                isDense: true,
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
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 34,
                              minHeight: 40,
                            ),
                            key: const ValueKey('new-poll'),
                            icon: const Icon(
                              Icons.poll_outlined,
                              color: Color(0xFF8696A0),
                              size: 20,
                            ),
                            tooltip: AppStrings.newPoll,
                            onPressed: _busy
                                ? null
                                : () => showCreatePollDialog(
                                    context,
                                    widget.groupId,
                                  ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 34,
                              minHeight: 40,
                            ),
                            icon: const Icon(
                              Icons.attach_file_rounded,
                              color: Color(0xFF8696A0),
                              size: 20,
                            ),
                            tooltip: AppStrings.attachImage,
                            onPressed: _busy ? null : _pickImage,
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Brand.accent,
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
        color: Brand.muted,
        borderRadius: BorderRadius.circular(8),
        border: const Border(left: BorderSide(color: Brand.accent, width: 3.5)),
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
                    color: Brand.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  replyingTo.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: Brand.inkSoft),
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
  PickedImage? _image;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await pickChatImage();
      if (picked != null && mounted) setState(() => _image = picked);
    } on RepositoryException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  /// Shows how the AI will word the draft; sends it from there if asked.
  Future<void> _preview() async {
    final rawText = _text.text.trim();
    if (rawText.isEmpty) return;
    final result = await showRewritePreview(
      context,
      groupId: widget.groupId,
      text: rawText,
      anonymous: _anonymous,
    );
    if (result?.choice == PreviewChoice.send && result?.previewId != null) {
      await _send(previewId: result!.previewId);
    }
  }

  Future<void> _send({String? previewId}) async {
    final rawText = _text.text.trim();
    if (rawText.isEmpty) {
      if (_image != null) {
        setState(() => _error = AppStrings.imageCaptionNeeded);
      }
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Replies are sent as a link to the message (API.md 50), not pasted
      // into the text, so the AI only rewrites what the sender wrote.
      final fullText = rawText;
      final replyToId = widget.replyingTo?.id;

      final repo = ref.read(groupRepositoryProvider);
      final image = _image;
      final attachmentId = image == null
          ? null
          : await repo.uploadAttachment(
              widget.groupId,
              bytes: image.bytes,
              filename: image.filename,
            );
      if (previewId != null) {
        await repo.sendPreview(
          widget.groupId,
          previewId,
          isAnonymous: _anonymous,
          attachmentId: attachmentId,
          replyToId: replyToId,
        );
      } else {
        await repo.sendMessage(
          widget.groupId,
          text: fullText,
          isAnonymous: _anonymous,
          attachmentId: attachmentId,
          replyToId: replyToId,
        );
      }
      _text.clear();
      _anonymous = false;
      _image = null;
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
            border: Border.all(color: Brand.border),
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
                  color: Brand.muted,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Brand.muted),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 16, color: Brand.ink),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Messages undergo AI clarity rephrasing and Controller approval before publishing.',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.3,
                          color: Brand.inkSoft,
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
                  color: _anonymous ? Brand.muted : Brand.canvas,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _anonymous ? Brand.accent : Brand.border,
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
                              activeColor: Brand.accent,
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
                              color: Brand.ink,
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
                          color: Brand.inkSoft,
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

              if (_image != null) ...[
                PendingImagePreview(
                  image: _image!,
                  anonymous: _anonymous,
                  onRemove: _busy ? null : () => setState(() => _image = null),
                ),
                const SizedBox(height: 8),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: const ValueKey('preview-button'),
                  onPressed: _busy ? null : _preview,
                  style: TextButton.styleFrom(
                    foregroundColor: Brand.ink,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.auto_awesome, size: 15),
                  label: const Text(
                    AppStrings.previewAction,
                    style: TextStyle(fontSize: 12),
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
                        border: Border.all(color: Brand.border),
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
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 34,
                              minHeight: 40,
                            ),
                            icon: const Icon(
                              Icons.sentiment_satisfied_alt_outlined,
                              color: Color(0xFF8696A0),
                              size: 22,
                            ),
                            tooltip: AppStrings.emojiTooltip,
                            onPressed: () => showEmojiPicker(context, _text),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _text,
                              minLines: 1,
                              maxLines: 5,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                hintText: 'Message',
                                filled: false,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                isDense: true,
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
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 34,
                              minHeight: 40,
                            ),
                            icon: const Icon(
                              Icons.attach_file_rounded,
                              color: Color(0xFF8696A0),
                              size: 20,
                            ),
                            tooltip: AppStrings.attachImage,
                            onPressed: _busy ? null : _pickImage,
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Brand.ink,
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

/// A pending submission with a way to take it back before review.
class _PendingWithWithdraw extends ConsumerStatefulWidget {
  const _PendingWithWithdraw({required this.item});

  final MyMessageStatus item;

  @override
  ConsumerState<_PendingWithWithdraw> createState() =>
      _PendingWithWithdrawState();
}

class _PendingWithWithdrawState extends ConsumerState<_PendingWithWithdraw> {
  var _busy = false;

  Future<void> _withdraw() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: const Text(AppStrings.withdrawConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(AppStrings.withdraw),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(groupRepositoryProvider).withdrawMessage(widget.item.id);
      ref.invalidate(myMessagesProvider(widget.item.groupId));
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.withdrawn)),
      );
    } on RepositoryException catch (e) {
      ref.invalidate(myMessagesProvider(widget.item.groupId));
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _PendingSubmission(item: widget.item),
        TextButton.icon(
          key: ValueKey('withdraw-${widget.item.id}'),
          onPressed: _busy ? null : _withdraw,
          style: TextButton.styleFrom(
            foregroundColor: Brand.inkSoft,
            visualDensity: VisualDensity.compact,
          ),
          icon: const Icon(Icons.undo, size: 15),
          label: const Text(
            AppStrings.withdraw,
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

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
        border: Border.all(color: Brand.border),
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
                color: Brand.accent,
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
                              color: Brand.ink,
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
                            color: Brand.muted,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Brand.border),
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
                                  color: Brand.ink,
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
                        color: Brand.canvas,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Brand.border),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.auto_fix_high,
                                size: 13,
                                color: Brand.ink,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'AI Synthesizing Non-Adversarial Phrasing…',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Brand.inkSoft,
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
          border: Border.all(color: Brand.border),
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
              style: TextStyle(fontSize: 11, color: Brand.inkSoft),
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
        color: Brand.accent,
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
    return Icon(icon, size: size, color: Brand.ink);
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
        border: Border.all(color: Brand.border),
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
                        color: Brand.ink,
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
                            color: Brand.accent,
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
                          style: TextStyle(fontSize: 11, color: Brand.inkFaint),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          memberStr,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Brand.inkSoft,
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
                color: Brand.canvas,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Brand.border),
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
                      style: TextStyle(fontSize: 11.5, color: Brand.inkSoft),
                    ),
                  ),
                  Text(
                    _clock(waitingSince!),
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Brand.inkFaint,
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
              border: Border.all(color: Brand.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: Brand.ink),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Brand.ink,
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
        color: anonymous ? Brand.muted : Brand.accent,
        shape: BoxShape.circle,
        border: Border.all(color: anonymous ? Brand.border : Brand.accent),
      ),
      child: anonymous
          ? const Icon(
              Icons.visibility_off_outlined,
              size: 14,
              color: Brand.ink,
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
        color: Brand.muted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Brand.border),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 10, color: Brand.ink),
          SizedBox(width: 2),
          Text(
            'Shielded',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Brand.inkSoft,
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

const _emojis = [
  '😀', '😊', '🙂', '😉', '😅', '😂', '🙏', '👍', '👎', '👏', //
  '🙌', '💪', '🤝', '👀', '🤔', '😐', '😕', '😟', '😢', '😮', //
  '😤', '😴', '🥳', '🎉', '✅', '❌', '⚠️', '💡', '📌', '🔥', //
  '❤️', '💙', '⭐', '☕', '📅', '⏰', '📈', '📉', '🚀', '🛠️',
];

/// A small emoji palette that inserts the picked emoji at the cursor.
Future<void> showEmojiPicker(
  BuildContext context,
  TextEditingController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        child: GridView.count(
          key: const ValueKey('emoji-picker'),
          crossAxisCount: 8,
          shrinkWrap: true,
          children: [
            for (final emoji in _emojis)
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  _insertAtCursor(controller, emoji);
                  Navigator.of(sheetContext).pop();
                },
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 24)),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

void _insertAtCursor(TextEditingController controller, String insert) {
  final value = controller.value;
  final selection = value.selection;
  final start = selection.isValid ? selection.start : value.text.length;
  final end = selection.isValid ? selection.end : value.text.length;
  final text = value.text.replaceRange(start, end, insert);
  controller.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: start + insert.length),
  );
}
