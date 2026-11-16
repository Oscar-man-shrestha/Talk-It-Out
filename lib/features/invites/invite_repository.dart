import 'dart:math';

import 'package:dio/dio.dart';
import 'package:talk_it_out/core/api/api_guard.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/mock/mock_board.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/mock/run_mock.dart';
import 'package:talk_it_out/core/models/enums.dart';
import 'package:talk_it_out/core/models/group_member.dart';

/// A shareable link that lets people join a group (`API.md` 61).
class InviteLink {
  const InviteLink({
    required this.code,
    required this.url,
    required this.appUrl,
    this.expiresAt,
    this.maxUses,
    this.uses = 0,
  });

  factory InviteLink.fromJson(Map<String, dynamic> json) => InviteLink(
    code: json['code'] as String? ?? '',
    url: json['url'] as String? ?? '',
    appUrl: json['app_url'] as String? ?? '',
    expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? '')
        ?.toLocal(),
    maxUses: (json['max_uses'] as num?)?.toInt(),
    uses: (json['uses'] as num?)?.toInt() ?? 0,
  );

  final String code;

  /// Opens the web app (and the installed app once app links are set up).
  final String url;

  /// Opens the installed Android app directly.
  final String appUrl;
  final DateTime? expiresAt;
  final int? maxUses;
  final int uses;
}

/// What someone sees before joining.
class InvitePreview {
  const InvitePreview({
    required this.code,
    required this.groupId,
    required this.agenda,
    required this.memberCount,
    this.invitedBy,
    this.alreadyMember = false,
  });

  factory InvitePreview.fromJson(Map<String, dynamic> json) {
    final group = json['group'] is Map
        ? Map<String, dynamic>.from(json['group'] as Map)
        : const <String, dynamic>{};
    return InvitePreview(
      code: json['code'] as String? ?? '',
      groupId: group['id'] as String? ?? '',
      agenda: group['agenda'] as String? ?? '',
      memberCount: (group['member_count'] as num?)?.toInt() ?? 0,
      invitedBy: json['invited_by'] as String?,
      alreadyMember: json['already_member'] == true,
    );
  }

  final String code;
  final String groupId;
  final String agenda;
  final int memberCount;
  final String? invitedBy;
  final bool alreadyMember;
}

abstract interface class InviteRepository {
  /// [expiresInDays] is 1, 7, 30 or null for no expiry.
  Future<InviteLink> createInvite(
    String groupId, {
    int? expiresInDays = 7,
    int? maxUses,
  });

  Future<List<InviteLink>> listInvites(String groupId);

  Future<void> revokeInvite(String groupId, String code);

  Future<InvitePreview> previewInvite(String code);

  /// Joins and returns the group id (also when already a member).
  Future<String> acceptInvite(String code);
}

class ApiInviteRepository implements InviteRepository {
  ApiInviteRepository(this._dio);

  final Dio _dio;

  @override
  Future<InviteLink> createInvite(
    String groupId, {
    int? expiresInDays = 7,
    int? maxUses,
  }) {
    return guardApi(() async {
      final response = await _dio.post(
        '/groups/$groupId/invites',
        data: {'expires_in_days': expiresInDays, 'max_uses': maxUses},
      );
      return InviteLink.fromJson(asJsonMap(response.data));
    });
  }

  @override
  Future<List<InviteLink>> listInvites(String groupId) {
    return guardApi(() async {
      final response = await _dio.get('/groups/$groupId/invites');
      final items = asJsonMap(response.data)['items'];
      return [
        if (items is List)
          for (final x in items)
            if (x is Map) InviteLink.fromJson(Map<String, dynamic>.from(x)),
      ];
    });
  }

  @override
  Future<void> revokeInvite(String groupId, String code) {
    return guardApi(() async {
      await _dio.delete('/groups/$groupId/invites/$code');
    });
  }

  @override
  Future<InvitePreview> previewInvite(String code) {
    return guardApi(() async {
      final response = await _dio.get('/invites/$code');
      return InvitePreview.fromJson(asJsonMap(response.data));
    });
  }

  @override
  Future<String> acceptInvite(String code) {
    return guardApi(() async {
      final response = await _dio.post('/invites/$code/accept');
      return asJsonMap(response.data)['group_id'] as String? ?? '';
    });
  }
}

class _MockInvite {
  _MockInvite(this.link, this.groupId);
  InviteLink link;
  final String groupId;
  bool revoked = false;
}

/// In-memory invites for the demo build. The demo user joins as
/// `MockIds.priya`'s account.
class MockInviteRepository implements InviteRepository {
  MockInviteRepository(this._controls, this._board, this._me);

  final MockControls _controls;
  final MockBoard _board;
  final String _me;
  final _invites = <String, _MockInvite>{};
  final _random = Random();

  static const _alphabet = 'abcdefghjkmnpqrstuvwxyz23456789';

  bool _usable(_MockInvite i) =>
      !i.revoked &&
      (i.link.expiresAt == null || i.link.expiresAt!.isAfter(DateTime.now())) &&
      (i.link.maxUses == null || i.link.uses < i.link.maxUses!);

  @override
  Future<InviteLink> createInvite(
    String groupId, {
    int? expiresInDays = 7,
    int? maxUses,
  }) {
    return runMock(_controls, () {
      final code = List.generate(
        10,
        (_) => _alphabet[_random.nextInt(_alphabet.length)],
      ).join();
      final link = InviteLink(
        code: code,
        url: 'https://talkitout.app/#/join/$code',
        appUrl: 'talkitout://app/join/$code',
        expiresAt: expiresInDays == null
            ? null
            : DateTime.now().add(Duration(days: expiresInDays)),
        maxUses: maxUses,
      );
      _invites[code] = _MockInvite(link, groupId);
      return link;
    });
  }

  @override
  Future<List<InviteLink>> listInvites(String groupId) {
    return runMock(
      _controls,
      () => [
        for (final i in _invites.values.toList().reversed)
          if (i.groupId == groupId && _usable(i)) i.link,
      ],
    );
  }

  @override
  Future<void> revokeInvite(String groupId, String code) =>
      runMock(_controls, () => _invites[code]?.revoked = true);

  _MockInvite _find(String code) {
    final i = _invites[code];
    if (i == null || !_usable(i)) {
      throw const RepositoryException(
        code: 'invite_invalid',
        message: 'This invite link has expired or was turned off.',
      );
    }
    return i;
  }

  @override
  Future<InvitePreview> previewInvite(String code) {
    return runMock(_controls, () {
      final i = _find(code);
      final group = _board.groups.firstWhere((g) => g.id == i.groupId);
      final members = _board.membersByGroup[i.groupId] ?? const <GroupMember>[];
      return InvitePreview(
        code: code,
        groupId: i.groupId,
        agenda: group.agenda,
        memberCount: members.length,
        invitedBy: _board.meName,
        alreadyMember: members.any((m) => m.userId == _me),
      );
    });
  }

  @override
  Future<String> acceptInvite(String code) {
    return runMock(_controls, () {
      final i = _invites[code];
      final members = i == null
          ? const <GroupMember>[]
          : (_board.membersByGroup[i.groupId] ?? const <GroupMember>[]);
      if (i != null && members.any((m) => m.userId == _me)) return i.groupId;
      final usable = _find(code);
      _board.membersByGroup[usable.groupId] = [
        ...members,
        GroupMember(userId: _me, name: 'You', role: GroupRole.contributor),
      ];
      usable.link = InviteLink(
        code: usable.link.code,
        url: usable.link.url,
        appUrl: usable.link.appUrl,
        expiresAt: usable.link.expiresAt,
        maxUses: usable.link.maxUses,
        uses: usable.link.uses + 1,
      );
      return usable.groupId;
    });
  }
}
