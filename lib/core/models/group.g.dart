// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Group _$GroupFromJson(Map<String, dynamic> json) => _Group(
  id: json['id'] as String,
  agenda: json['agenda'] as String,
  controllerId: json['controller_id'] as String,
  sourcePostId: json['source_post_id'] as String?,
  createdAt: DateTime.parse(json['created_at'] as String),
  myRole: $enumDecode(
    _$GroupRoleEnumMap,
    json['my_role'],
    unknownValue: GroupRole.contributor,
  ),
  pendingCount: (json['pending_count'] as num?)?.toInt(),
);

Map<String, dynamic> _$GroupToJson(_Group instance) => <String, dynamic>{
  'id': instance.id,
  'agenda': instance.agenda,
  'controller_id': instance.controllerId,
  'source_post_id': instance.sourcePostId,
  'created_at': instance.createdAt.toIso8601String(),
  'my_role': _$GroupRoleEnumMap[instance.myRole]!,
  'pending_count': instance.pendingCount,
};

const _$GroupRoleEnumMap = {
  GroupRole.controller: 'controller',
  GroupRole.contributor: 'contributor',
};
