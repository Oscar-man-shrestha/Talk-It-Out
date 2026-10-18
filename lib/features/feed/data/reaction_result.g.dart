// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reaction_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ReactionResult _$ReactionResultFromJson(Map<String, dynamic> json) =>
    _ReactionResult(
      reactionCount: (json['reaction_count'] as num).toInt(),
      myReaction: json['my_reaction'] as String?,
    );

Map<String, dynamic> _$ReactionResultToJson(_ReactionResult instance) =>
    <String, dynamic>{
      'reaction_count': instance.reactionCount,
      'my_reaction': instance.myReaction,
    };
