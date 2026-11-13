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

  /// Submissions are outcomes of your own messages; moderation is review work
  /// waiting for you as a controller.
  bool _inFilter(AppNotification item, String filter) {
    switch (filter) {
      case 'submissions':
        return item.type == NotificationType.messageRejected;
      case 'moderation':
        return item.type == NotificationType.messagePendingReview;
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
        context.go('/groups/${item.group.id}/review');
      case NotificationType.messageRejected:
        context.go('/groups/${item.group.id}/mine');
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
                    tooltip: AppStrings.navGroups,
                    onPressed: () => context.go('/groups'),
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
                        color: unread == 0 ? _kSurfaceMuted : _kPrimary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$unread new',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          color: unread == 0 ? _kTextSecondary : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: unread == 0
                      ? null
                      : () => _guard(
                          ref.read(notificationsProvider.notifier).markAllRead,
                        ),
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
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    AppStrings.notificationsEmpty,
                    style: TextStyle(fontSize: 12.5, color: _kTextSecondary),
                  ),
                ),
              ),
            for (final item in visible) ...[
              _NotificationCard(item: item, onOpen: () => _open(item)),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 4),

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
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: _kTextTertiary,
                  ),
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
                      Icons.arrow_forward,
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
