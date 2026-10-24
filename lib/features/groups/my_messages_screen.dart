import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talk_it_out/core/models/enums.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/core/ui/screen_async.dart';
import 'package:talk_it_out/core/widgets/async_body.dart';
import 'package:talk_it_out/features/groups/data/my_message_status.dart';
import 'package:talk_it_out/features/groups/group_providers.dart';

/// Status-only ledger for the signed-in member's submissions.
///
/// Message bodies, rewrites, controller notes, and review metadata deliberately
/// belong only to controller review screens and are never rendered here.
class MyMessagesScreen extends ConsumerWidget {
  const MyMessagesScreen({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(myMessagesProvider(groupId));
    final items = messages.asData?.value ?? const <MyMessageStatus>[];
    final screenWidth = MediaQuery.sizeOf(context).width;
    final hPad = screenWidth > 860 ? (screenWidth - 800) / 2 : 16.0;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.myMessages)),
      body: AsyncBody(
        status: asyncStatus(messages, isEmpty: items.isEmpty),
        errorMessage: errorText(messages.error),
        onRetry: () => ref.invalidate(myMessagesProvider(groupId)),
        empty: const Center(child: Text(AppStrings.myMessagesEmpty)),
        child: ListView.separated(
          padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 32),
          itemCount: items.length,
          itemBuilder: (context, index) =>
              _MessageStatusCard(item: items[index]),
          separatorBuilder: (context, index) => const SizedBox(height: 12),
        ),
      ),
    );
  }
}

class _MessageStatusCard extends StatelessWidget {
  const _MessageStatusCard({required this.item});

  final MyMessageStatus item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
    final createdAt = item.createdAt.toLocal();
    final timestamp =
        '${localizations.formatShortDate(createdAt)} '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(createdAt))}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _StatusIcon(status: item.status),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _statusLabel(item.status),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(timestamp, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            if (item.isAnonymous)
              const Icon(
                Icons.visibility_off_outlined,
                semanticLabel: AppStrings.anonymousCheckbox,
              ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(MessageStatus status) {
    switch (status) {
      case MessageStatus.pending:
        return AppStrings.statusPending;
      case MessageStatus.accepted:
        return AppStrings.statusAccepted;
      case MessageStatus.rejected:
        return AppStrings.statusRejected;
    }
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final MessageStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (status) {
      MessageStatus.pending => (Icons.schedule_outlined, colorScheme.primary),
      MessageStatus.accepted => (
        Icons.check_circle_outline,
        colorScheme.primary,
      ),
      MessageStatus.rejected => (
        Icons.cancel_outlined,
        colorScheme.onSurfaceVariant,
      ),
    };
    return Icon(icon, color: color, semanticLabel: _statusLabel(status));
  }

  String _statusLabel(MessageStatus status) {
    switch (status) {
      case MessageStatus.pending:
        return AppStrings.statusPending;
      case MessageStatus.accepted:
        return AppStrings.statusAccepted;
      case MessageStatus.rejected:
        return AppStrings.statusRejected;
    }
  }
}
