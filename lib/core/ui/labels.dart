import 'package:talk_it_out/core/models/enums.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';

String roleLabel(GroupRole role) {
  return role == GroupRole.controller
      ? AppStrings.roleController
      : AppStrings.roleContributor;
}

String messageStatusLabel(MessageStatus status) {
  switch (status) {
    case MessageStatus.pending:
      return AppStrings.statusPending;
    case MessageStatus.accepted:
      return AppStrings.statusAccepted;
    case MessageStatus.rejected:
      return AppStrings.statusRejected;
  }
}

String relevanceText(RelevanceLabel label) {
  switch (label) {
    case RelevanceLabel.relevant:
      return AppStrings.relevanceRelevant;
    case RelevanceLabel.borderline:
      return AppStrings.relevanceBorderline;
    case RelevanceLabel.offTopic:
      return AppStrings.relevanceOffTopic;
  }
}

/// "12 Oct, 2:30 PM" (the year is added when it is not this year).
String formatWhen(DateTime value, {DateTime? now}) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final local = value.toLocal();
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'AM' : 'PM';
  final thisYear = (now ?? DateTime.now()).toLocal().year == local.year;
  final day = '${local.day} ${months[local.month - 1]}';
  return '${thisYear ? day : '$day ${local.year}'}, $hour12:$minute $period';
}
