import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:talk_it_out/core/models/enums.dart';

part 'group.freezed.dart';
part 'group.g.dart';

@freezed
abstract class Group with _$Group {
  const factory Group({
    required String id,
    required String agenda,
    required String controllerId,
    String? sourcePostId,
    required DateTime createdAt,
    @JsonKey(unknownEnumValue: GroupRole.contributor) required GroupRole myRole,
    int? pendingCount,
  }) = _Group;

  factory Group.fromJson(Map<String, dynamic> json) => _$GroupFromJson(json);
}
