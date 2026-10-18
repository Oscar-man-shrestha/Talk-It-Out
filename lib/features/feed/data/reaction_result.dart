import 'package:freezed_annotation/freezed_annotation.dart';

part 'reaction_result.freezed.dart';
part 'reaction_result.g.dart';

@freezed
abstract class ReactionResult with _$ReactionResult {
  const factory ReactionResult({
    required int reactionCount,
    String? myReaction,
  }) = _ReactionResult;

  factory ReactionResult.fromJson(Map<String, dynamic> json) =>
      _$ReactionResultFromJson(json);
}
