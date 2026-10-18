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

String formatWhen(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}
