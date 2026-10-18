import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:talk_it_out/core/models/enums.dart';

part 'group_member.freezed.dart';
part 'group_member.g.dart';

@freezed
abstract class GroupMember with _$GroupMember {
  const factory GroupMember({
    required String userId,
    required String name,
    @JsonKey(unknownEnumValue: GroupRole.contributor) required GroupRole role,
  }) = _GroupMember;

  factory GroupMember.fromJson(Map<String, dynamic> json) =>
      _$GroupMemberFromJson(json);
}
