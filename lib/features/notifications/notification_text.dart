import 'package:talk_it_out/core/models/enums.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/features/notifications/data/app_notification.dart';

String _short(String? title) {
  final t = (title ?? '').trim();
  if (t.isEmpty) return 'your question';
  return t.length > 70 ? '${t.substring(0, 67)}...' : t;
}

String notificationText(AppNotification item) {
  switch (item.type) {
    case NotificationType.messageRejected:
      return AppStrings.messageRejected(item.group?.agenda ?? 'a group');
    case NotificationType.messagePendingReview:
      return AppStrings.messagePendingReview(item.group?.agenda ?? 'a group');
    case NotificationType.mentioned:
      return AppStrings.mentioned(item.group?.agenda ?? 'a group');
    case NotificationType.questionAnswered:
      return AppStrings.questionAnswered(_short(item.post?.title));
    case NotificationType.answerBest:
      return AppStrings.answerBest(_short(item.post?.title));
    case NotificationType.unknown:
      return AppStrings.notificationGeneric;
  }
}
