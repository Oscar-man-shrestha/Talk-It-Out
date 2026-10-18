// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_member.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GroupMember _$GroupMemberFromJson(Map<String, dynamic> json) => _GroupMember(
  userId: json['user_id'] as String,
  name: json['name'] as String,
  role: $enumDecode(
    _$GroupRoleEnumMap,
    json['role'],
    unknownValue: GroupRole.contributor,
  ),
);

Map<String, dynamic> _$GroupMemberToJson(_GroupMember instance) =>
    <String, dynamic>{
      'user_id': instance.userId,
      'name': instance.name,
      'role': _$GroupRoleEnumMap[instance.role]!,
    };

const _$GroupRoleEnumMap = {
  GroupRole.controller: 'controller',
  GroupRole.contributor: 'contributor',
};
