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

    /// Group info set by the controller (`API.md` 67).
    @Default('') String description,
    @Default('') String rules,
    @Default(0) int memberCount,

    /// Your own settings for this group: muted groups do not count toward
    /// the Groups badge; pinned groups stay at the top.
    @Default(false) bool muted,
    @Default(false) bool pinned,
  }) = _Group;

  factory Group.fromJson(Map<String, dynamic> json) => _$GroupFromJson(json);
}
