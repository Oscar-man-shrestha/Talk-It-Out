/// Someone asked you to join a group (`API.md` 69). You join only by
/// accepting.
class GroupInvitation {
  const GroupInvitation({
    required this.id,
    required this.groupId,
    required this.agenda,
    this.memberCount = 0,
    this.invitedBy,
    required this.createdAt,
  });

  factory GroupInvitation.fromJson(Map<String, dynamic> json) {
    final group = json['group'] is Map
        ? Map<String, dynamic>.from(json['group'] as Map)
        : const <String, dynamic>{};
    return GroupInvitation(
      id: json['id'] as String? ?? '',
      groupId: group['id'] as String? ?? '',
      agenda: group['agenda'] as String? ?? '',
      memberCount: (group['member_count'] as num?)?.toInt() ?? 0,
      invitedBy: json['invited_by'] as String?,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  final String id;
  final String groupId;
  final String agenda;
  final int memberCount;
  final String? invitedBy;
  final DateTime createdAt;
}

/// An invitation the controller sent that has not been answered yet.
class PendingInvitation {
  const PendingInvitation({
    required this.id,
    required this.userId,
    required this.name,
    required this.createdAt,
  });

  factory PendingInvitation.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : const <String, dynamic>{};
    return PendingInvitation(
      id: json['id'] as String? ?? '',
      userId: user['id'] as String? ?? '',
      name: user['name'] as String? ?? 'Someone',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  final String id;
  final String userId;
  final String name;
  final DateTime createdAt;
}
