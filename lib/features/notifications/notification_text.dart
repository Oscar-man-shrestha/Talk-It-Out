import 'package:talk_it_out/core/models/enums.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/features/notifications/data/app_notification.dart';

String notificationText(AppNotification item) {
  switch (item.type) {
    case NotificationType.messageRejected:
      return AppStrings.messageRejected(item.group.agenda);
    case NotificationType.messagePendingReview:
      return AppStrings.messagePendingReview(item.group.agenda);
    case NotificationType.unknown:
      return AppStrings.notificationGeneric;
  }
}
