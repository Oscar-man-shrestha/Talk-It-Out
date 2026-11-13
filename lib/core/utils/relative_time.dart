/// Short, human-readable age of [time] ("just now", "5m ago", "3d ago").
/// Older than a week falls back to a plain date.
String relativeTime(DateTime time, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final diff = current.difference(time);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  final local = time.toLocal();
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final sameYear = local.year == current.toLocal().year;
  final day = '${local.day} ${months[local.month - 1]}';
  return sameYear ? day : '$day ${local.year}';
}
