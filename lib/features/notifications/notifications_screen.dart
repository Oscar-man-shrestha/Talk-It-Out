import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/ui/screen_async.dart';
import 'package:talk_it_out/core/widgets/async_body.dart';
import 'package:talk_it_out/features/notifications/data/app_notification.dart';
import 'package:talk_it_out/features/notifications/notification_providers.dart';

// Stitch Monochrome Precision tokens
const _kPrimary = Color(0xFF000000);
const _kSurface = Color(0xFFFFFFFF);
const _kSurfaceMuted = Color(0xFFF4F4F5);
const _kBorderSubtle = Color(0xFFE4E4E7);
const _kTextPrimary = Color(0xFF09090B);
const _kTextSecondary = Color(0xFF71717A);
const _kTextTertiary = Color(0xFFA1A1AA);

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String _filter = 'all'; // 'all', 'submissions', 'moderation'
  bool _diffExpanded = false;
  bool _appliedRewrite = false;
  bool _controllerNoteExpanded = false;
  bool _allMarkedRead = false;

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsProvider);
    final items = notifications.value ?? const <AppNotification>[];
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 900;
    final isMobile = screenWidth < 600;
    final hPad = isDesktop ? (screenWidth - 860) / 2 : (isMobile ? 12.0 : 20.0);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: _kBorderSubtle)),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _kPrimary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.diversity_3,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'TALK IT OUT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: _kTextPrimary,
                            ),
                          ),
                          SizedBox(width: 4),
                          Text(
                            '•',
                            style: TextStyle(
                              fontSize: 10,
                              color: _kTextPrimary,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Talk It Out Alerts',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _kTextSecondary,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.chat_bubble_outline,
                      size: 20,
                      color: _kTextSecondary,
                    ),
                    onPressed: () {},
                  ),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: _kPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 17,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: AsyncBody(
        status: asyncStatus(notifications, isEmpty: false),
        errorMessage: errorText(notifications.error),
        onRetry: () {
          ref.invalidate(notificationsProvider);
          ref.invalidate(unreadCountProvider);
        },
        empty: const SizedBox.shrink(),
        child: ListView(
          padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 40),
          children: [
            // Sub-header Action Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Alerts',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        color: _kTextPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _allMarkedRead ? _kSurfaceMuted : _kPrimary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _allMarkedRead ? '0 new' : '2 new',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          color: _allMarkedRead
                              ? _kTextSecondary
                              : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _allMarkedRead = true);
                    for (final item in items) {
                      if (item.isUnread) {
                        ref
                            .read(notificationRepositoryProvider)
                            .markRead(item.id);
                      }
                    }
                    ref.invalidate(unreadCountProvider);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    backgroundColor: _kSurfaceMuted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(
                    Icons.done_all,
                    size: 15,
                    color: _kTextSecondary,
                  ),
                  label: const Text(
                    'Mark all read',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Filter Chips Navigation
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _AlertChip(
                    label: 'All (5)',
                    active: _filter == 'all',
                    onTap: () => setState(() => _filter = 'all'),
                  ),
                  const SizedBox(width: 8),
                  _AlertChip(
                    label: 'Submissions (2)',
                    active: _filter == 'submissions',
                    onTap: () => setState(() => _filter = 'submissions'),
                  ),
                  const SizedBox(width: 8),
                  _AlertChip(
                    label: 'Moderation (2)',
                    active: _filter == 'moderation',
                    onTap: () => setState(() => _filter = 'moderation'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Item 1: Submission Approved (Category: submissions)
            if (_filter == 'all' || _filter == 'submissions') ...[
              _StitchAlertContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (!_allMarkedRead) ...[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: _kPrimary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        const Icon(
                          Icons.check_circle,
                          size: 15,
                          color: _kPrimary,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'SUBMISSION APPROVED',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: _kTextPrimary,
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          '12m ago',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: _kTextTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: _kTextPrimary,
                        ),
                        children: [
                          TextSpan(text: 'Your anonymous proposal on '),
                          TextSpan(
                            text: 'Remote Webcam Monitoring',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(
                            text: ' was approved by the Controller and published to ',
                          ),
                          TextSpan(
                            text: 'AI Ethics & Workplace Policy',
                            style: TextStyle(
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          TextSpan(text: '.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: _kBorderSubtle),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _kSurfaceMuted,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.fingerprint,
                                size: 12,
                                color: _kTextTertiary,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'hash: #a8f9-40e1',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontFamily: 'monospace',
                                  color: _kTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => context.go('/groups'),
                          child: const Row(
                            children: [
                              Text(
                                'View in Chat',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: _kTextPrimary,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward,
                                size: 14,
                                color: _kTextPrimary,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Item 2: AI Rewrite Ready (Category: moderation)
            if (_filter == 'all' || _filter == 'moderation') ...[
              _StitchAlertContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (!_allMarkedRead) ...[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: _kPrimary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        const Icon(
                          Icons.auto_awesome,
                          size: 15,
                          color: _kPrimary,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'AI REWRITE READY',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: _kTextPrimary,
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          '45m ago',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: _kTextTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: _kTextPrimary,
                        ),
                        children: [
                          TextSpan(
                            text: 'AI synthesized a new structured phrasing for your draft in ',
                          ),
                          TextSpan(
                            text: 'Product Launch Governance',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(
                            text: ' to reduce friction while preserving your core argument.',
                          ),
                        ],
                      ),
                    ),
                    if (_diffExpanded) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _kSurfaceMuted,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SYNTHESIZED REPLACEMENT',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: _kTextTertiary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '“We propose deferring milestone Beta-2 until automated unit validation passes the 98% threshold, avoiding production regressions.”',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontFamily: 'monospace',
                                  color: _kTextPrimary,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () =>
                              setState(() => _diffExpanded = !_diffExpanded),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            side: const BorderSide(color: _kBorderSubtle),
                            minimumSize: const Size(0, 32),
                          ),
                          icon: const Icon(Icons.difference_outlined, size: 14),
                          label: const Text(
                            'Inspect Diff',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: _kTextPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () =>
                              setState(() => _appliedRewrite = true),
                          style: FilledButton.styleFrom(
                            backgroundColor: _kPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            minimumSize: const Size(0, 32),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.check, size: 14),
                          label: Text(
                            _appliedRewrite ? 'Applied' : 'Apply',
                            style: const TextStyle(fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Item 3: Controller Action (Category: moderation)
            if (_filter == 'all' || _filter == 'moderation') ...[
              _StitchAlertContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 15,
                          color: _kTextSecondary,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'CONTROLLER ACTION',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: _kTextSecondary,
                          ),
                        ),
                        Spacer(),
                        Text(
                          '2h ago',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: _kTextTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: _kTextSecondary,
                        ),
                        children: [
                          TextSpan(
                            text: 'Elena Vance',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _kTextPrimary,
                            ),
                          ),
                          TextSpan(text: ' accepted 3 pending messages into '),
                          TextSpan(
                            text: 'Design Review & Critique',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _kTextPrimary,
                            ),
                          ),
                          TextSpan(text: ' live stage.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _kSurfaceMuted,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Batch clearance ID: #CR-8820',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: _kTextTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Item 4: Submission Rejected (Category: submissions)
            if (_filter == 'all' || _filter == 'submissions') ...[
              _StitchAlertContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.cancel_outlined,
                          size: 15,
                          color: _kTextSecondary,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'SUBMISSION REJECTED',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: _kTextSecondary,
                          ),
                        ),
                        Spacer(),
                        Text(
                          'Yesterday',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: _kTextTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: _kTextSecondary,
                        ),
                        children: [
                          TextSpan(text: 'Your submission in '),
                          TextSpan(
                            text: 'Quarterly OKRs',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _kTextPrimary,
                            ),
                          ),
                          TextSpan(text: ' was rejected by the Controller: '),
                          TextSpan(
                            text: 'Off-topic for current agenda stage.',
                            style: TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => setState(
                        () =>
                            _controllerNoteExpanded = !_controllerNoteExpanded,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _controllerNoteExpanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 16,
                            color: _kTextPrimary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _controllerNoteExpanded
                                ? 'Hide Controller Note'
                                : 'Read Controller Note',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: _kTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_controllerNoteExpanded) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _kSurfaceMuted,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '“The agenda is currently evaluating Q3 headcount allocation rather than tech debt remediation. Please resubmit this during the infrastructure sync on Thursday.”',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: _kTextSecondary,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Item 5: New Discussion Spawned (Category: all)
            if (_filter == 'all') ...[
              _StitchAlertContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.account_tree_outlined,
                          size: 15,
                          color: _kTextSecondary,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'NEW DISCUSSION SPAWNED',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: _kTextSecondary,
                          ),
                        ),
                        Spacer(),
                        Text(
                          '2d ago',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: _kTextTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: _kTextPrimary,
                        ),
                        children: [
                          TextSpan(
                            text: 'David Chen',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(
                            text: ' created a new group from your Public Feed post on ',
                          ),
                          TextSpan(
                            text: 'Local Sandboxing',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: '.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Origin: Public Feed #309',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontFamily: 'monospace',
                            color: _kTextTertiary,
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () => context.go('/groups'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _kPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            minimumSize: const Size(0, 32),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.group_add, size: 14),
                          label: const Text(
                            'Join Group',
                            style: TextStyle(fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Bottom caught-up state
            const Center(
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 20,
                    color: _kTextTertiary,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Caught up on recent group activity',
                    style: TextStyle(fontSize: 11.5, color: _kTextTertiary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertChip extends StatelessWidget {
  const _AlertChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? _kPrimary : _kSurface,
      borderRadius: BorderRadius.circular(999),
      elevation: active ? 1 : 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: active ? _kPrimary : _kBorderSubtle),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : _kTextSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _StitchAlertContainer extends StatelessWidget {
  const _StitchAlertContainer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: child,
    );
  }
}
