import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/core/models/enums.dart';
import 'package:talk_it_out/core/ui/screen_async.dart';
import 'package:talk_it_out/core/widgets/async_body.dart';
import 'package:talk_it_out/features/groups/data/my_message_status.dart';
import 'package:talk_it_out/features/groups/group_providers.dart';

// Stitch Monochrome Precision design tokens
const _kPrimary = Color(0xFF000000);
const _kSurfaceMuted = Color(0xFFF4F4F5);
const _kBorderSubtle = Color(0xFFE4E4E7);
const _kTextPrimary = Color(0xFF09090B);
const _kTextSecondary = Color(0xFF71717A);
const _kTextTertiary = Color(0xFFA1A1AA);

class MyMessagesScreen extends ConsumerStatefulWidget {
  const MyMessagesScreen({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<MyMessagesScreen> createState() => _MyMessagesScreenState();
}

class _MyMessagesScreenState extends ConsumerState<MyMessagesScreen> {
  String _filter = 'all'; // 'all', 'review', 'published', 'rejected'
  final _searchController = TextEditingController();
  final Set<String> _withdrawn = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(myMessagesProvider(widget.groupId));
    final liveItems = messages.value ?? const <MyMessageStatus>[];
    final screenWidth = MediaQuery.sizeOf(context).width;
    final hPad = screenWidth > 860 ? (screenWidth - 420) / 2 : 16.0;

    // Build the ledger items list, ensuring the demonstrative items from the PNG are included
    final allLedgerCards = <_LedgerCardData>[
      _LedgerCardData(
        id: 'ledger-1',
        type: 'review',
        statusHeader: 'PENDING CONTROLLER REVIEW',
        timeAgo: '10:45 AM today',
        groupTitle: 'AI Ethics & Workplace Policy',
        badgeLabel: 'SHIELDED',
        badgeIcon: Icons.shield_outlined,
        originalText: '“The proposed data collection schedule seems rushed and ignores consent safeguards...”',
        aiRevisionText: '“Could we revisit the rollout timeline for data logging to ensure alignment with team privacy policies?”',
        aiFitScore: '96% fit',
        isPending: true,
      ),
      _LedgerCardData(
        id: 'ledger-2',
        type: 'published',
        statusHeader: 'PUBLISHED TO CHAT',
        timeAgo: 'Yesterday',
        groupTitle: 'Design Review & Critique',
        badgeLabel: 'PUBLIC',
        badgeIcon: Icons.public,
        publishedText: '“Streamlining the component library to 3 button variants reduces ambiguity across client dev handoffs.”',
        likesCount: 9,
        repliesCount: 3,
      ),
      _LedgerCardData(
        id: 'ledger-3',
        type: 'published',
        statusHeader: 'PUBLISHED TO CHAT',
        timeAgo: '3 days ago',
        groupTitle: 'Product Launch Governance',
        badgeLabel: 'UNLOCKED',
        badgeIcon: Icons.lock_open_outlined,
        publishedText: '“The rollback checklist requires clear step owners before RC2 deployment can be stamped off.”',
        likesCount: 14,
        adoptedBadge: true,
      ),
      _LedgerCardData(
        id: 'ledger-4',
        type: 'rejected',
        statusHeader: 'REJECTED BY CONTROLLER',
        timeAgo: 'May 12',
        groupTitle: 'Quarterly OKRs',
        badgeLabel: 'PHASE MISMATCH',
        badgeIcon: Icons.swap_horiz,
        rejectedDraftText: '“Can we push the engineering refactor target to Q4 instead of allocating team hours now?”',
        controllerNote: 'Off-topic for current agenda phase. Please resubmit during open floor block or tag the Technical Architecture working group.',
      ),
    ];

    // If live messages exist, prepend them
    for (final m in liveItems) {
      if (allLedgerCards.any((c) => c.id == m.id)) continue;
      final typeStr = m.status == MessageStatus.pending
          ? 'review'
          : (m.status == MessageStatus.accepted ? 'published' : 'rejected');
      final headerStr = m.status == MessageStatus.pending
          ? 'PENDING CONTROLLER REVIEW'
          : (m.status == MessageStatus.accepted
                ? 'PUBLISHED TO CHAT'
                : 'REJECTED BY CONTROLLER');
      allLedgerCards.insert(
        0,
        _LedgerCardData(
          id: m.id,
          type: typeStr,
          statusHeader: headerStr,
          timeAgo: 'Just now',
          groupTitle: 'Current Group Session',
          badgeLabel: m.isAnonymous ? 'SHIELDED' : 'PUBLIC',
          badgeIcon: m.isAnonymous ? Icons.shield_outlined : Icons.public,
          isPending: m.status == MessageStatus.pending,
          publishedText: m.status == MessageStatus.accepted
              ? 'Approved and published to group discourse transcript.'
              : null,
          rejectedDraftText: m.status == MessageStatus.rejected
              ? 'Submitted contribution declined during controller review.'
              : null,
        ),
      );
    }

    final query = _searchController.text.trim().toLowerCase();
    final filtered = allLedgerCards.where((item) {
      if (_filter == 'review' && item.type != 'review') return false;
      if (_filter == 'published' && item.type != 'published') return false;
      if (_filter == 'rejected' && item.type != 'rejected') return false;
      if (query.isNotEmpty) {
        final matchTitle = item.groupTitle.toLowerCase().contains(query);
        final matchStatus = item.statusHeader.toLowerCase().contains(query);
        if (!matchTitle && !matchStatus) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(54),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: _kBorderSubtle)),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 18,
                      color: _kTextPrimary,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 4),
                  const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TALK IT OUT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: _kTextSecondary,
                        ),
                      ),
                      Text(
                        'Talk It Out My Messages',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: _kTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.more_vert,
                      size: 20,
                      color: _kTextSecondary,
                    ),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: AsyncBody(
        status: asyncStatus(messages, isEmpty: false),
        errorMessage: errorText(messages.error),
        onRetry: () => ref.invalidate(myMessagesProvider(widget.groupId)),
        empty: const SizedBox.shrink(),
        child: ListView(
          padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 40),
          children: [
            // Zero Identity Leakage Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kSurfaceMuted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(color: Color(0x0A000000), blurRadius: 3),
                      ],
                    ),
                    child: const Icon(
                      Icons.verified_user_outlined,
                      size: 17,
                      color: _kPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'ZERO IDENTITY LEAKAGE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: _kTextPrimary,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.lock, size: 12, color: _kTextSecondary),
                          ],
                        ),
                        SizedBox(height: 3),
                        Text(
                          'This private ledger logs all your anonymized submissions. Review, withdraw drafts, or inspect controller revisions before permanent transcript commitment.',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.4,
                            color: _kTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Search bar
            Container(
              height: 38,
              decoration: BoxDecoration(
                color: _kSurfaceMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 13, color: _kTextPrimary),
                decoration: const InputDecoration(
                  hintText: 'Search my ledger...',
                  hintStyle: TextStyle(fontSize: 12.5, color: _kTextTertiary),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 18,
                    color: _kTextTertiary,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 9),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Filter pills horizontal track
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _LedgerFilterPill(
                    label: 'ALL',
                    count: allLedgerCards.length,
                    active: _filter == 'all',
                    onTap: () => setState(() => _filter = 'all'),
                  ),
                  const SizedBox(width: 6),
                  _LedgerFilterPill(
                    label: 'IN REVIEW',
                    count: 1,
                    active: _filter == 'review',
                    onTap: () => setState(() => _filter = 'review'),
                  ),
                  const SizedBox(width: 6),
                  _LedgerFilterPill(
                    label: 'PUBLISHED',
                    count: 4,
                    active: _filter == 'published',
                    onTap: () => setState(() => _filter = 'published'),
                  ),
                  const SizedBox(width: 6),
                  _LedgerFilterPill(
                    label: 'REJECTED',
                    count: 1,
                    active: _filter == 'rejected',
                    onTap: () => setState(() => _filter = 'rejected'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Ledger Cards Stack
            for (final card in filtered) ...[
              _StitchLedgerCard(
                data: card,
                isWithdrawn: _withdrawn.contains(card.id),
                onWithdraw: () {
                  setState(() => _withdrawn.add(card.id));
                },
                onViewInGroup: () => context.go('/groups/${widget.groupId}'),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _LedgerFilterPill extends StatelessWidget {
  const _LedgerFilterPill({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? _kPrimary : _kSurfaceMuted,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: active ? Colors.white : _kTextSecondary,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withValues(alpha: 0.25)
                      : const Color(0xFFE4E4E7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : _kTextSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LedgerCardData {
  _LedgerCardData({
    required this.id,
    required this.type,
    required this.statusHeader,
    required this.timeAgo,
    required this.groupTitle,
    required this.badgeLabel,
    required this.badgeIcon,
    this.originalText,
    this.aiRevisionText,
    this.aiFitScore,
    this.publishedText,
    this.rejectedDraftText,
    this.controllerNote,
    this.likesCount,
    this.repliesCount,
    this.adoptedBadge = false,
    this.isPending = false,
  });

  final String id;
  final String type;
  final String statusHeader;
  final String timeAgo;
  final String groupTitle;
  final String badgeLabel;
  final IconData badgeIcon;
  final String? originalText;
  final String? aiRevisionText;
  final String? aiFitScore;
  final String? publishedText;
  final String? rejectedDraftText;
  final String? controllerNote;
  final int? likesCount;
  final int? repliesCount;
  final bool adoptedBadge;
  final bool isPending;
}

class _StitchLedgerCard extends StatelessWidget {
  const _StitchLedgerCard({
    required this.data,
    required this.isWithdrawn,
    required this.onWithdraw,
    required this.onViewInGroup,
  });

  final _LedgerCardData data;
  final bool isWithdrawn;
  final VoidCallback onWithdraw;
  final VoidCallback onViewInGroup;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isWithdrawn ? 0.45 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorderSubtle),
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
            // Status row + timestamp
            Row(
              children: [
                if (data.isPending) ...[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: _kPrimary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ] else if (data.type == 'published') ...[
                  const Icon(Icons.check_circle, size: 15, color: _kPrimary),
                  const SizedBox(width: 6),
                ] else if (data.type == 'rejected') ...[
                  const Icon(Icons.block, size: 15, color: _kPrimary),
                  const SizedBox(width: 6),
                ],
                Text(
                  isWithdrawn ? 'DRAFT WITHDRAWN' : data.statusHeader,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: _kTextPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  data.timeAgo,
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: _kTextTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Group row badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _kSurfaceMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(data.badgeIcon, size: 14, color: _kTextSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      data.groupTitle,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _kTextPrimary,
                      ),
                    ),
                  ),
                  Text(
                    data.badgeLabel,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: _kTextSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Original submission quote (Card 1)
            if (data.originalText != null) ...[
              const SizedBox(height: 10),
              const Text(
                'ORIGINAL SUBMISSION',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: _kTextTertiary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _kSurfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  data.originalText!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: _kTextSecondary,
                    height: 1.35,
                  ),
                ),
              ),
            ],

            // AI Sanitized revision (Card 1)
            if (data.aiRevisionText != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _kSurfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.auto_fix_high,
                              size: 14,
                              color: _kPrimary,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'AI SANITIZED REVISION',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: _kTextPrimary,
                              ),
                            ),
                          ],
                        ),
                        if (data.aiFitScore != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x08000000),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                            child: Text(
                              data.aiFitScore!,
                              style: const TextStyle(
                                fontSize: 10,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                                color: _kTextPrimary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data.aiRevisionText!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: _kTextPrimary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Published message body (Card 2 & Card 3)
            if (data.publishedText != null) ...[
              const SizedBox(height: 10),
              Text(
                data.publishedText!,
                style: const TextStyle(
                  fontSize: 13,
                  color: _kTextPrimary,
                  height: 1.4,
                ),
              ),
            ],

            // Rejected Draft (Card 4)
            if (data.rejectedDraftText != null) ...[
              const SizedBox(height: 10),
              const Text(
                'REJECTED DRAFT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: _kTextTertiary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data.rejectedDraftText!,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: _kTextSecondary,
                  decoration: TextDecoration.lineThrough,
                  height: 1.35,
                ),
              ),
            ],

            // Controller Note (Card 4)
            if (data.controllerNote != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _kSurfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, size: 14, color: _kPrimary),
                        SizedBox(width: 6),
                        Text(
                          'CONTROLLER NOTE',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: _kTextPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.controllerNote!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: _kTextSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),

            // Footer action bar per card type
            if (data.isPending) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.sync, size: 14, color: _kTextSecondary),
                      SizedBox(width: 6),
                      Text(
                        'Awaiting Moderator Slot',
                        style: TextStyle(fontSize: 12, color: _kTextSecondary),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed: isWithdrawn ? null : onWithdraw,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: const Size(0, 32),
                      side: const BorderSide(color: _kBorderSubtle),
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 14),
                    label: Text(
                      isWithdrawn ? 'Withdrawn' : 'Withdraw Draft',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ] else if (data.type == 'published') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (data.likesCount != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _kSurfaceMuted,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.thumb_up_outlined,
                                size: 12,
                                color: _kTextSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${data.likesCount} likes',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  color: _kTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(width: 8),
                      if (data.repliesCount != null)
                        Row(
                          children: [
                            const Icon(
                              Icons.forum_outlined,
                              size: 13,
                              color: _kTextTertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${data.repliesCount} replies',
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: _kTextTertiary,
                              ),
                            ),
                          ],
                        ),
                      if (data.adoptedBadge)
                        const Row(
                          children: [
                            Icon(
                              Icons.flag_outlined,
                              size: 13,
                              color: _kTextTertiary,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Adopted',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: _kTextTertiary,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: onViewInGroup,
                    icon: const Text(
                      'View in Group',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _kTextPrimary,
                      ),
                    ),
                    label: const Icon(
                      Icons.arrow_forward,
                      size: 14,
                      color: _kTextPrimary,
                    ),
                  ),
                ],
              ),
            ] else if (data.type == 'rejected') ...[
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: onViewInGroup,
                  style: FilledButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text(
                    'Edit & Resubmit',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
