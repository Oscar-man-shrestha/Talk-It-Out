import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/core/models/enums.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/core/ui/screen_async.dart';
import 'package:talk_it_out/core/utils/relative_time.dart';
import 'package:talk_it_out/core/widgets/async_body.dart';
import 'package:talk_it_out/features/notifications/data/app_notification.dart';
import 'package:talk_it_out/features/notifications/notification_providers.dart';
import 'package:talk_it_out/features/notifications/notification_text.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/core/ui/empty_state.dart';
import 'package:talk_it_out/core/ui/motion.dart';
import 'package:talk_it_out/core/ui/app_icons.dart';
import 'package:talk_it_out/core/ui/large_title_header.dart';

// Stitch Monochrome Precision tokens
const _kPrimary = Brand.accent;
const _kSurface = Brand.card;
const _kBorderSubtle = Brand.border;
const _kTextPrimary = Brand.ink;
const _kTextSecondary = Brand.inkSoft;
const _kTextTertiary = Brand.inkFaint;

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String _filter = 'all'; // 'all', 'submissions', 'moderation', 'community'

  /// Submissions are outcomes of your own messages; moderation is review work
  /// waiting for you as a controller.
  bool _inFilter(AppNotification item, String filter) {
    switch (filter) {
      case 'submissions':
        return item.type == NotificationType.messageRejected ||
            item.type == NotificationType.messagePublished;
      case 'moderation':
        return item.type == NotificationType.messagePendingReview;
      case 'community':
        return item.type == NotificationType.groupInvitation ||
            item.type == NotificationType.questionAnswered ||
            item.type == NotificationType.answerBest ||
            item.type == NotificationType.mentioned ||
            item.type == NotificationType.memberJoined ||
            item.type == NotificationType.questionLiked;
      default:
        return true;
    }
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorText(error) ?? AppStrings.errorGeneric)),
      );
    }
  }

  void _open(AppNotification item) {
    _guard(() => ref.read(notificationsProvider.notifier).markRead(item.id));
    switch (item.type) {
      case NotificationType.messagePendingReview:
        // The router sends anyone who is not this group's controller back.
        if (item.group case final g?) context.go('/groups/${g.id}/review');
      case NotificationType.messageRejected:
        if (item.group case final g?) context.go('/groups/${g.id}/mine');
      case NotificationType.mentioned:
        if (item.group case final g?) context.go('/groups/${g.id}');
      case NotificationType.groupInvitation:
        // Answered on the Groups screen, where the invitation is shown.
        context.go('/groups');
      case NotificationType.questionAnswered:
      case NotificationType.answerBest:
      case NotificationType.questionLiked:
        if (item.post case final p?) context.push('/feed/${p.id}');
      case NotificationType.messagePublished:
        if (item.group case final g?) context.go('/groups/${g.id}');
      case NotificationType.memberJoined:
        if (item.group case final g?) context.push('/groups/${g.id}/members');
      case NotificationType.unknown:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsProvider);
    final items = notifications.value ?? const <AppNotification>[];
    final unread = items.where((item) => item.isUnread).length;
    final visible = items.where((item) => _inFilter(item, _filter)).toList();
    int count(String filter) =>
        items.where((item) => _inFilter(item, filter)).length;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 900;
    final isMobile = screenWidth < 600;
    final hPad = isDesktop ? (screenWidth - 860) / 2 : (isMobile ? 12.0 : 20.0);

    return Scaffold(
      backgroundColor: Brand.canvas,
      appBar: LargeTitleHeader(
        title: 'Alerts',
        subtitle: '$unread new',
        actions: [
          TextButton.icon(
            onPressed: unread == 0
                ? null
                : () => _guard(
                    ref.read(notificationsProvider.notifier).markAllRead,
                  ),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              disabledForegroundColor: HeroInk.inkSoft,
              backgroundColor: HeroInk.fill,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 36),
              shape: const StadiumBorder(side: BorderSide(color: HeroInk.line)),
            ),
            icon: const Icon(PhosphorIconsRegular.checks, size: 15),
            label: const Text(
              'Mark all read',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
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
            // Filter Chips Navigation
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _AlertChip(
                    label: 'All (${count('all')})',
                    active: _filter == 'all',
                    onTap: () => setState(() => _filter = 'all'),
                  ),
                  const SizedBox(width: 8),
                  _AlertChip(
                    label: 'Submissions (${count('submissions')})',
                    active: _filter == 'submissions',
                    onTap: () => setState(() => _filter = 'submissions'),
                  ),
                  const SizedBox(width: 8),
                  _AlertChip(
                    label: 'Moderation (${count('moderation')})',
                    active: _filter == 'moderation',
                    onTap: () => setState(() => _filter = 'moderation'),
                  ),
                  const SizedBox(width: 8),
                  _AlertChip(
                    label: 'Community (${count('community')})',
                    active: _filter == 'community',
                    onTap: () => setState(() => _filter = 'community'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: EmptyState(
                  key: ValueKey('notifications-empty'),
                  inList: true,
                  icon: Icons.notifications_none,
                  title: "You're all caught up",
                  body: AppStrings.notificationsEmpty,
                  points: [
                    (
                      PhosphorIconsRegular.listChecks,
                      'When a message you sent is published or not published',
                    ),
                    (
                      PhosphorIconsRegular.chatsCircle,
                      'When someone answers your question',
                    ),
                    (
                      PhosphorIconsRegular.userPlus,
                      'When you are added to a group',
                    ),
                  ],
                ),
              ),
            for (final (i, item) in visible.indexed) ...[
              Reveal(
                index: i,
                child: PressScale(
                  child: _NotificationCard(
                    item: item,
                    onOpen: () => _open(item),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 4),

            // Bottom caught-up state
            const Center(
              child: Column(
                children: [
                  Icon(
                    PhosphorIconsRegular.checkCircle,
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

/// One notification, drawn in the same Stitch card style as before.
///
/// It says only what happened and in which group: never message text, a
/// rewrite, or a rejection reason.
class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onOpen});

  final AppNotification item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final (icon, label, action) = switch (item.type) {
      NotificationType.messagePendingReview => (
        Icons.rate_review_outlined,
        'REVIEW REQUESTED',
        AppStrings.openReview,
      ),
      NotificationType.messageRejected => (
        Icons.cancel_outlined,
        'SUBMISSION REJECTED',
        AppStrings.openMyMessages,
      ),
      NotificationType.groupInvitation => (
        PhosphorIconsRegular.userPlus,
        'GROUP INVITATION',
        'Accept or decline',
      ),
      NotificationType.mentioned => (
        PhosphorIconsRegular.at,
        'MENTIONED',
        'Open the chat',
      ),
      NotificationType.questionAnswered => (
        PhosphorIconsRegular.chatsCircle,
        'NEW ANSWER',
        'Read the answer',
      ),
      NotificationType.answerBest => (
        PhosphorIconsRegular.crown,
        'BEST ANSWER',
        'See your answer',
      ),
      NotificationType.messagePublished => (
        PhosphorIconsRegular.checkCircle,
        'PUBLISHED',
        'Open the chat',
      ),
      NotificationType.memberJoined => (
        PhosphorIconsRegular.userPlus,
        'NEW MEMBER',
        'See members',
      ),
      NotificationType.questionLiked => (
        Icons.favorite_border,
        'NEW LIKES',
        'See your question',
      ),
      NotificationType.unknown => (
        Icons.notifications_none,
        'NOTIFICATION',
        null,
      ),
    };
    final unread = item.isUnread;
    final tone = unread ? _kTextPrimary : _kTextSecondary;

    return InkWell(
      onTap: action == null ? null : onOpen,
      borderRadius: BorderRadius.circular(12),
      child: _StitchAlertContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (unread) ...[
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
                Icon(icon, size: 15, color: unread ? _kPrimary : tone),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: tone,
                    ),
                  ),
                ),
                Text(
                  relativeTime(item.createdAt),
                  style: const TextStyle(fontSize: 11, color: _kTextTertiary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              notificationText(item),
              style: TextStyle(fontSize: 12.5, height: 1.45, color: tone),
            ),
            if (action != null) ...[
              const SizedBox(height: 10),
              const Divider(height: 1, color: _kBorderSubtle),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      action,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _kTextPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      PhosphorIconsRegular.arrowRight,
                      size: 14,
                      color: _kTextPrimary,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
