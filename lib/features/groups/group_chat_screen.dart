import 'dart:async';

import 'package:flutter/material.dart';
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

class GroupChatScreen extends ConsumerWidget {
  const GroupChatScreen({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(groupDetailProvider(groupId));
    final messages = ref.watch(groupMessagesProvider(groupId));
    final items = messages.value ?? const <PublishedMessage>[];
    final isController = group.value?.myRole == GroupRole.controller;

    final members = ref.watch(membersProvider(groupId)).value?.length;
    final mine = ref.watch(myMessagesProvider(groupId)).value;
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
    final hPad = screenWidth > 640 ? (screenWidth - 576) / 2 : 16.0;

    return Scaffold(
      backgroundColor: Colors.white,
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
                context.push('/groups/$groupId/members');
              } else if (value == 'mine') {
                context.push('/groups/$groupId/mine');
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'members',
                child: Text(AppStrings.membersTitle),
              ),
              PopupMenuItem(value: 'mine', child: Text(AppStrings.myMessages)),
            ],
          ),
          if (isController)
            IconButton(
              tooltip: AppStrings.reviewTitle,
              onPressed: () => context.push('/groups/$groupId/review'),
              icon: const Icon(Icons.fact_check_outlined),
            ),
          Material(
            color: Colors.black,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => context.go('/profile'),
              child: const SizedBox(
                width: 32,
                height: 32,
                child: Icon(Icons.person, size: 18, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _MarkGroupOpened(groupId: groupId),
          if (group.value != null)
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 0),
              child: _SessionBanner(
                agenda: group.value!.agenda,
                role: roleLabel(group.value!.myRole),
                memberCount: members,
                onMembers: () => context.push('/groups/$groupId/members'),
                onMine: () => context.push('/groups/$groupId/mine'),
                waitingSince: waitingSince,
              ),
            ),
          if (group.value != null)
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 0),
              child: _AgendaAnchorPin(agenda: group.value!.agenda),
            ),
          Expanded(
            child: AsyncBody(
              status: asyncStatus(
                messages,
                isEmpty: items.isEmpty && pendingMine.isEmpty,
              ),
              errorMessage: errorText(messages.error),
              onRetry: () => ref.invalidate(groupMessagesProvider(groupId)),
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
                          color: Color(0xFFF4F4F5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.chat_bubble_outline_rounded,
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
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 20),
                itemCount:
                    items.length +
                    pendingMine.length +
                    (pendingMine.isNotEmpty ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index < items.length) {
                    return PublishedMessageTile(message: items[index]);
                  }
                  final pendingIndex = index - items.length;
                  if (pendingIndex < pendingMine.length) {
                    return _PendingSubmission(item: pendingMine[pendingIndex]);
                  }
                  return const _ReviewingPulsePill();
                },
              ),
            ),
          ),
          if (group.value != null && !isController)
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE4E4E7))),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: hPad > 16 ? hPad - 16 : 0,
              ),
              child: MessageComposer(groupId: groupId),
            ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4E4E7)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.push_pin_outlined,
            size: 18,
            color: Color(0xFF09090B),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Goal: $agenda',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF09090B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Published message tile ───────────────────────────────────────────────────

class PublishedMessageTile extends StatefulWidget {
  const PublishedMessageTile({required this.message, super.key});

  final PublishedMessage message;

  @override
  State<PublishedMessageTile> createState() => _PublishedMessageTileState();
}

class _PublishedMessageTileState extends State<PublishedMessageTile> {
  bool _liked = false;
  late int _likes;

  @override
  void initState() {
    super.initState();
    _likes = widget.message.id.hashCode.abs() % 10;
  }

  void _toggleLike() {
    setState(() {
      _liked = !_liked;
      _likes += _liked ? 1 : -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAnonymous = widget.message.displaySender == null;
    final sender =
        widget.message.displaySender?.name ?? AppStrings.anonymousUser;

    return Semantics(
      label: '$sender. ${widget.message.text}',
      child: Container(
        padding: const EdgeInsets.all(14),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SenderMark(name: sender, anonymous: isAnonymous),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Text(
                        sender,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF09090B),
                        ),
                      ),
                      if (isAnonymous) const _ShieldedChip(),
                      Text(
                        '• ${_clock(widget.message.publishedAt)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFA1A1AA),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F4F5),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFE4E4E7)),
                  ),
                  child: const Text(
                    'PUBLISHED',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                      color: Color(0xFF71717A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Body
            Text(
              widget.message.text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Color(0xFF09090B),
              ),
            ),
            const SizedBox(height: 10),

            // AI approval badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F4F5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF4F4F5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isAnonymous
                        ? Icons.verified_user_outlined
                        : Icons.auto_awesome,
                    size: 16,
                    color: const Color(0xFF09090B),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      isAnonymous
                          ? 'Identity verified anonymously \u2022 Approved by Controller'
                          : 'AI Rewritten & Approved by Controller',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF71717A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Actions row
            Row(
              children: [
                GestureDetector(
                  onTap: _toggleLike,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _liked ? Icons.thumb_up : Icons.thumb_up_outlined,
                        size: 16,
                        color: _liked
                            ? const Color(0xFF09090B)
                            : const Color(0xFF71717A),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$_likes',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _liked
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: _liked
                              ? const Color(0xFF09090B)
                              : const Color(0xFF71717A),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.mode_comment_outlined,
                      size: 16,
                      color: Color(0xFF71717A),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Reply',
                      style: TextStyle(fontSize: 12, color: Color(0xFF71717A)),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  '#${widget.message.id}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFA1A1AA),
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

// ─── Pending submission card ──────────────────────────────────────────────────

class _PendingSubmission extends StatelessWidget {
  const _PendingSubmission({required this.item});

  final MyMessageStatus item;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                          child: const Text(
                            'YOU',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
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
                    const SizedBox(height: 10),

                    // AI Proposed Phrasing block
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE4E4E7)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(
                                Icons.auto_fix_high,
                                size: 14,
                                color: Color(0xFF09090B),
                              ),
                              SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  'AI Proposed Phrasing:',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF71717A),
                                  ),
                                ),
                              ),
                              Text(
                                'Synthesizing\u2026',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFFA1A1AA),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Generating non-adversarial framing for controller moderation\u2026',
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              height: 1.45,
                              color: Color(0xFF09090B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Footer
                    Row(
                      children: const [
                        Icon(
                          Icons.schedule,
                          size: 15,
                          color: Color(0xFFA1A1AA),
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'AI rewrite completed. In Controller queue.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF71717A),
                            ),
                          ),
                        ),
                      ],
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE4E4E7)),
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

// ─── Animated ping dot ────────────────────────────────────────────────────────

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

// ─── Spinning icon ────────────────────────────────────────────────────────────

class _SpinningIcon extends StatelessWidget {
  const _SpinningIcon({required this.icon, required this.size});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: size, color: const Color(0xFF09090B));
  }
}

// ─── Message composer ─────────────────────────────────────────────────────────

class MessageComposer extends ConsumerStatefulWidget {
  const MessageComposer({required this.groupId, super.key});

  final String groupId;

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
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(groupRepositoryProvider)
          .sendMessage(
            widget.groupId,
            text: _text.text,
            isAnonymous: _anonymous,
          );
      _text.clear();
      _anonymous = false;
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
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Container(
          padding: const EdgeInsets.all(12),
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

              // Input area
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE4E4E7)),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _text,
                      minLines: 2,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Draft your contribution to the agenda...',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: Color(0xFFA1A1AA),
                        ),
                        filled: true,
                        fillColor: Colors.transparent,
                        contentPadding: EdgeInsets.all(12),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFE4E4E7),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _anonymous,
                            onChanged: _busy
                                ? null
                                : (v) =>
                                      setState(() => _anonymous = v ?? false),
                            activeColor: Colors.black,
                            visualDensity: VisualDensity.compact,
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    AppStrings.anonymousCheckbox,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF09090B),
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    AppStrings.anonymousDisclosure,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF71717A),
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: FilledButton(
                  onPressed: _busy ? null : _send,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
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
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              AppStrings.send,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(Icons.send_rounded, size: 16),
                          ],
                        ),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
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
    this.waitingSince,
  });

  final String agenda;
  final String role;
  final int? memberCount;
  final VoidCallback onMembers;
  final VoidCallback onMine;
  final DateTime? waitingSince;

  @override
  Widget build(BuildContext context) {
    final memberStr = memberCount == null
        ? 'Active Agenda'
        : memberCount == 1
        ? '1 member \u2022 Active Agenda'
        : '$memberCount members \u2022 Active Agenda';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E4E7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agenda,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: Color(0xFF09090B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            role.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const Text(
                          '\u2022',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFFA1A1AA),
                          ),
                        ),
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
          ),
          // Stage ticker - shows when there are pending messages
          if (waitingSince != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
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
                      style: TextStyle(fontSize: 12, color: Color(0xFF71717A)),
                    ),
                  ),
                  Text(
                    _clock(waitingSince!),
                    style: const TextStyle(
                      fontSize: 11,
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

// ─── Banner button ────────────────────────────────────────────────────────────

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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE4E4E7)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: const Color(0xFF09090B)),
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
      width: 32,
      height: 32,
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
              size: 16,
              color: Color(0xFF09090B),
            )
          : Text(
              _initials(name),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE4E4E7)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 11, color: Color(0xFF09090B)),
          SizedBox(width: 2),
          Text(
            'Shielded',
            style: TextStyle(
              fontSize: 11,
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
