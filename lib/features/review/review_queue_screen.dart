import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/core/ui/labels.dart';
import 'package:talk_it_out/core/ui/screen_async.dart';
import 'package:talk_it_out/core/widgets/async_body.dart';
import 'package:talk_it_out/features/groups/group_providers.dart';
import 'package:talk_it_out/features/review/data/raw_message.dart';
import 'package:talk_it_out/features/review/review_providers.dart';

// Stitch Monochrome Precision tokens
const _kPrimary = Color(0xFF000000);
const _kSurface = Color(0xFFFFFFFF);
const _kSurfaceMuted = Color(0xFFF4F4F5);
const _kSurfaceSubtle = Color(0xFFFAFAFA);
const _kBorderSubtle = Color(0xFFE4E4E7);
const _kTextPrimary = Color(0xFF09090B);
const _kTextSecondary = Color(0xFF71717A);
const _kTextTertiary = Color(0xFFA1A1AA);

class ReviewQueueScreen extends ConsumerStatefulWidget {
  const ReviewQueueScreen({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<ReviewQueueScreen> createState() => _ReviewQueueScreenState();
}

class _ReviewQueueScreenState extends ConsumerState<ReviewQueueScreen> {
  int _activeTab = 0; // 0: Pending, 1: Approved, 2: Rejected
  double _relevanceThreshold = 70.0;
  int _anonymityFilter = 0; // 0: All, 1: Anonymous Only, 2: Named Only
  String _priorityMode = 'Normal FIFO';

  void _openFilterModal() {
    double tempThreshold = _relevanceThreshold;
    int tempAnon = _anonymityFilter;
    String tempPriority = _priorityMode;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.tune, size: 18, color: _kTextPrimary),
                          SizedBox(width: 8),
                          Text(
                            'Review Queue Filters',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _kTextPrimary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 20,
                          color: _kTextSecondary,
                        ),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Relevance Threshold Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Minimum Relevance Score',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _kTextPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _kSurfaceMuted,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: _kBorderSubtle),
                        ),
                        child: Text(
                          '> ${tempThreshold.toInt()}%',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _kTextPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: tempThreshold,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    activeColor: _kPrimary,
                    inactiveColor: _kBorderSubtle,
                    onChanged: (val) {
                      setModalState(() => tempThreshold = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Anonymity Type Filter
                  const Text(
                    'Identity Shielding Filter',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final entry in [
                        (0, 'All'),
                        (1, 'Anonymous Only'),
                        (2, 'Attributed Only'),
                      ])
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: InkWell(
                              onTap: () {
                                setModalState(() => tempAnon = entry.$1);
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: tempAnon == entry.$1
                                      ? _kPrimary
                                      : _kSurfaceMuted,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: tempAnon == entry.$1
                                        ? _kPrimary
                                        : _kBorderSubtle,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  entry.$2,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: tempAnon == entry.$1
                                        ? Colors.white
                                        : _kTextSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Priority Sorting
                  const Text(
                    'Queue Priority Ordering',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: _kSurfaceSubtle,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kBorderSubtle),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: tempPriority,
                        isExpanded: true,
                        style: const TextStyle(
                          fontSize: 13,
                          color: _kTextPrimary,
                        ),
                        icon: const Icon(
                          Icons.expand_more,
                          size: 18,
                          color: _kTextSecondary,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Normal FIFO',
                            child: Text('Normal FIFO (Chronological)'),
                          ),
                          DropdownMenuItem(
                            value: 'High Tension First',
                            child: Text('High Tension / Escalations First'),
                          ),
                          DropdownMenuItem(
                            value: 'Consensus Blockers First',
                            child: Text('Consensus Blockers First'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => tempPriority = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Bottom Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: _kBorderSubtle),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            minimumSize: const Size(0, 44),
                          ),
                          onPressed: () {
                            setModalState(() {
                              tempThreshold = 70.0;
                              tempAnon = 0;
                              tempPriority = 'Normal FIFO';
                            });
                          },
                          child: const Text(
                            'Reset',
                            style: TextStyle(
                              fontSize: 13,
                              color: _kTextSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _kPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            minimumSize: const Size(0, 44),
                          ),
                          onPressed: () {
                            setState(() {
                              _relevanceThreshold = tempThreshold;
                              _anonymityFilter = tempAnon;
                              _priorityMode = tempPriority;
                            });
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Review Queue filters applied.'),
                                duration: Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: const Text(
                            'Apply Filters',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(reviewQueueProvider(widget.groupId));
    final groupAsync = ref.watch(groupDetailProvider(widget.groupId));
    final groupAgenda =
        groupAsync.value?.agenda ?? 'AI Ethics & Workplace Policy';
    final pending = queue.value ?? const <RawMessage>[];
    final ready = pending.where((m) => m.rewrittenText != null).length;
    // The queue endpoint lists pending messages only. Relevance is advisory
    // and never hides a message, so only the identity filter narrows this.
    final items = _activeTab != 0
        ? const <RawMessage>[]
        : pending.where((m) {
            if (_anonymityFilter == 1) return m.isAnonymous;
            if (_anonymityFilter == 2) return !m.isAnonymous;
            return true;
          }).toList();
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 900;
    final isMobile = screenWidth < 600;
    final hPad = isDesktop ? (screenWidth - 860) / 2 : (isMobile ? 12.0 : 20.0);

    return Scaffold(
      backgroundColor: _kSurface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          decoration: const BoxDecoration(
            color: _kSurface,
            border: Border(bottom: BorderSide(color: _kBorderSubtle)),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? hPad : (isMobile ? 12.0 : 16.0),
              ),
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
                          letterSpacing: 0.8,
                          color: _kTextSecondary,
                        ),
                      ),
                      Text(
                        'Talk It Out • Review Queue',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: _kTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Queue options',
                    icon: const Icon(
                      Icons.more_vert,
                      size: 20,
                      color: _kTextSecondary,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: _kBorderSubtle),
                    ),
                    color: _kSurface,
                    elevation: 3,
                    onSelected: (val) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${pending.length} pending • $ready rewrites ready',
                          ),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(
                        value: 'health',
                        height: 36,
                        child: Row(
                          children: [
                            Icon(
                              Icons.monitor_heart_outlined,
                              size: 15,
                              color: _kTextSecondary,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Queue status',
                              style: TextStyle(
                                fontSize: 12,
                                color: _kTextPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: AsyncBody(
        status: asyncStatus(queue, isEmpty: pending.isEmpty),
        errorMessage: errorText(queue.error),
        onRetry: () => ref.invalidate(reviewQueueProvider(widget.groupId)),
        empty: _EmptyReviewState(hPad: hPad),
        child: ListView(
          padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 48),
          children: [
            // 1. Topic Context Header Sub-bar (matches HTML 3)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: _kPrimary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          groupAgenda.toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: _kTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: _kSurfaceMuted,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sensors, size: 12, color: _kTextPrimary),
                      SizedBox(width: 4),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                          color: _kTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 2. Operational Buffer Stats Card (matches HTML 3)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _kSurfaceSubtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kBorderSubtle),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${pending.length} awaiting moderation',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _kTextPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: _kPrimary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'ACTIVE',
                              style: TextStyle(
                                fontSize: 9,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            ready == 1
                                ? '1 rewrite ready'
                                : '$ready rewrites ready',
                            style: TextStyle(
                              fontSize: 11,
                              color: _kTextSecondary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '•',
                            style: TextStyle(color: _kTextTertiary),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${pending.length - ready} rewriting',
                            style: TextStyle(
                              fontSize: 11,
                              color: _kTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: _openFilterModal,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color:
                            _relevanceThreshold != 70.0 || _anonymityFilter != 0
                            ? _kPrimary
                            : _kSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              _relevanceThreshold != 70.0 ||
                                  _anonymityFilter != 0
                              ? _kPrimary
                              : _kBorderSubtle,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.tune,
                            size: 16,
                            color:
                                _relevanceThreshold != 70.0 ||
                                    _anonymityFilter != 0
                                ? Colors.white
                                : _kTextPrimary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Filter',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color:
                                  _relevanceThreshold != 70.0 ||
                                      _anonymityFilter != 0
                                  ? Colors.white
                                  : _kTextPrimary,
                            ),
                          ),
                          if (_relevanceThreshold != 70.0 ||
                              _anonymityFilter != 0) ...[
                            const SizedBox(width: 4),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 3. Filter Navigation Pills (matches HTML 3)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterPill(
                    label: 'Pending',
                    count: '${pending.length}',
                    selected: _activeTab == 0,
                    onTap: () => setState(() => _activeTab = 0),
                  ),
                  const SizedBox(width: 8),
                  _FilterPill(
                    label: 'Approved',
                    count: '–',
                    selected: _activeTab == 1,
                    onTap: () => setState(() => _activeTab = 1),
                  ),
                  const SizedBox(width: 8),
                  _FilterPill(
                    label: 'Rejected',
                    count: '–',
                    selected: _activeTab == 2,
                    onTap: () => setState(() => _activeTab = 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 4. Queue Cards List
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    _activeTab == 0
                        ? AppStrings.reviewEmpty
                        : 'Reviewed messages are not listed here.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: _kTextSecondary,
                    ),
                  ),
                ),
              ),
            for (final message in items) ...[
              _QueueCard(
                message: message,
                groupId: widget.groupId,
                onReject: () async {
                  try {
                    await ref.read(reviewRepositoryProvider).reject(message.id);
                    ref.invalidate(reviewQueueProvider(widget.groupId));
                  } on RepositoryException catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(e.message)));
                    }
                  }
                },
              ),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 10),
            // Bottom Tip Indicator (matches HTML 3)
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.swipe, size: 16, color: _kTextTertiary),
                SizedBox(width: 6),
                Text(
                  'Tip: Open a message to compare it with its rewrite',
                  style: TextStyle(fontSize: 11, color: _kTextTertiary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? _kPrimary : _kSurfaceMuted,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: selected ? Colors.white : _kTextSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.25)
                    : _kSurface,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                count,
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : _kTextSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({
    required this.message,
    required this.groupId,
    required this.onReject,
  });

  final RawMessage message;
  final String groupId;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final isAnon = message.isAnonymous;
    // Controllers see who sent every message, including anonymous ones.
    final senderTitle = message.senderName;
    final relevance = message.relevanceScore != null
        ? '${(message.relevanceScore! * 100).round()}% Relevance'
        : 'Relevance pending';
    final label = message.relevanceLabel;
    final tag = label == null
        ? (isAnon ? 'SENT AS ANONYMOUS' : 'SENT WITH NAME')
        : relevanceText(label).toUpperCase();
    final intent = message.intentPreservationScore;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Metadata Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isAnon ? _kPrimary : _kSurfaceMuted,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: isAnon
                        ? const Icon(
                            Icons.visibility_off,
                            size: 13,
                            color: Colors.white,
                          )
                        : Text(
                            message.senderName.isNotEmpty
                                ? message.senderName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _kTextPrimary,
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    senderTitle,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kTextPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    formatWhen(message.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: _kTextTertiary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _kSurface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _kBorderSubtle),
                ),
                child: Text(
                  relevance,
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
          const SizedBox(height: 10),

          // Tag Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _kBorderSubtle),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.gavel, size: 12, color: _kTextPrimary),
                const SizedBox(width: 4),
                Text(
                  tag,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: _kTextPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Raw Input Block
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kBorderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.format_quote, size: 13, color: _kTextTertiary),
                    SizedBox(width: 3),
                    Text(
                      'RAW INPUT',
                      style: TextStyle(
                        fontSize: 9,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: _kTextTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '“${message.originalText}”',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: _kTextPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Neutral Synthesis Panel
          if (message.rewrittenText != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kBorderSubtle),
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
                            size: 13,
                            color: _kTextSecondary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'NEUTRAL SYNTHESIS',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: _kTextSecondary,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        intent == null
                            ? ''
                            : 'Intent ${(intent * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 9,
                          fontFamily: 'monospace',
                          color: _kTextTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '“${message.rewrittenText}”',
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                      color: _kTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Action Row (Reject / Rerun / Review & Decide)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: onReject,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _kSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _kBorderSubtle),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 18,
                        color: _kTextSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () {},
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _kSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _kBorderSubtle),
                      ),
                      child: const Icon(
                        Icons.cached,
                        size: 18,
                        color: _kTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              FilledButton(
                onPressed: () =>
                    context.push('/groups/$groupId/review/${message.id}'),
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
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Review & Decide',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 5),
                    Icon(Icons.arrow_forward, size: 14),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyReviewState extends StatelessWidget {
  const _EmptyReviewState({required this.hPad});

  final double hPad;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: hPad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _kSurfaceMuted,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kBorderSubtle),
              ),
              child: const Icon(
                Icons.task_alt_outlined,
                size: 24,
                color: _kTextSecondary,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              AppStrings.reviewEmpty,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _kTextSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
