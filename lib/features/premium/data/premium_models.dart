/// Premium state from `GET /billing/entitlements` (`API.md` 71). The
/// server decides; the app only displays it.
class Entitlements {
  const Entitlements({
    required this.premium,
    this.status,
    this.provider,
    this.expiresAt,
    this.willRenew = false,
  });

  static const free = Entitlements(premium: false);

  final bool premium;

  /// `active`, `grace`, `cancelled`, `expired`, or null (never subscribed).
  final String? status;
  final String? provider;
  final DateTime? expiresAt;
  final bool willRenew;

  factory Entitlements.fromJson(Map<String, dynamic> json) => Entitlements(
    premium: json['premium'] == true,
    status: json['status'] as String?,
    provider: json['provider'] as String?,
    expiresAt: json['expires_at'] is String
        ? DateTime.tryParse(json['expires_at'] as String)
        : null,
    willRenew: json['will_renew'] == true,
  );
}

/// One day of activity in a group.
class DayCount {
  const DayCount(this.date, this.count);
  final DateTime date;
  final int count;
}

/// Group Insights (`API.md` 71): published text and counts only. The
/// breakdowns are null unless the group has at least 5 members.
class GroupInsights {
  const GroupInsights({
    required this.windowDays,
    required this.memberCount,
    required this.breakdownsAvailable,
    required this.messages,
    required this.daily,
    required this.pending,
    required this.accepted,
    required this.rejected,
    required this.topWords,
    this.reviewMedianMinutes,
    this.participants,
    this.anonymousMessages,
    this.busiestHours,
  });

  final int windowDays;
  final int memberCount;
  final bool breakdownsAvailable;
  final int messages;
  final List<DayCount> daily;
  final int pending;
  final int accepted;
  final int rejected;
  final int? reviewMedianMinutes;
  final int? participants;
  final int? anonymousMessages;
  final List<(int hour, int count)>? busiestHours;
  final List<(String word, int count)> topWords;

  factory GroupInsights.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v) => v is num ? v.toInt() : 0;
    int? asIntOrNull(Object? v) => v is num ? v.toInt() : null;
    final hours = json['busiest_hours'];
    return GroupInsights(
      windowDays: asInt(json['window_days']),
      memberCount: asInt(json['member_count']),
      breakdownsAvailable: json['breakdowns_available'] == true,
      messages: asInt(json['messages']),
      daily: [
        for (final d in (json['daily'] as List? ?? const []))
          if (d is Map && d['date'] is String)
            DayCount(
              DateTime.tryParse(d['date'] as String) ?? DateTime(1970),
              asInt(d['count']),
            ),
      ],
      pending: asInt(json['pending']),
      accepted: asInt(json['accepted']),
      rejected: asInt(json['rejected']),
      reviewMedianMinutes: asIntOrNull(json['review_median_minutes']),
      participants: asIntOrNull(json['participants']),
      anonymousMessages: asIntOrNull(json['anonymous_messages']),
      busiestHours: hours is List
          ? [
              for (final h in hours)
                if (h is Map) (asInt(h['hour']), asInt(h['count'])),
            ]
          : null,
      topWords: [
        for (final w in (json['top_words'] as List? ?? const []))
          if (w is Map && w['word'] is String)
            (w['word'] as String, asInt(w['count'])),
      ],
    );
  }
}
