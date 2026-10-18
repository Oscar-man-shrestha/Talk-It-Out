// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reaction_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ReactionResult {

 int get reactionCount; String? get myReaction;
/// Create a copy of ReactionResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReactionResultCopyWith<ReactionResult> get copyWith => _$ReactionResultCopyWithImpl<ReactionResult>(this as ReactionResult, _$identity);

  /// Serializes this ReactionResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ReactionResult;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReactionResult&&(identical(other.reactionCount, _this.reactionCount) || other.reactionCount == _this.reactionCount)&&(identical(other.myReaction, _this.myReaction) || other.myReaction == _this.myReaction));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ReactionResult;
  return Object.hash(runtimeType,_this.reactionCount,_this.myReaction);
}

@override
String toString() {
  final _this = this as ReactionResult;
  return 'ReactionResult(reactionCount: ${_this.reactionCount}, myReaction: ${_this.myReaction})';
}


}

/// @nodoc
abstract mixin class $ReactionResultCopyWith<$Res>  {
  factory $ReactionResultCopyWith(ReactionResult value, $Res Function(ReactionResult) _then) = _$ReactionResultCopyWithImpl;
@useResult
$Res call({
 int reactionCount, String? myReaction
});




}
/// @nodoc
class _$ReactionResultCopyWithImpl<$Res>
    implements $ReactionResultCopyWith<$Res> {
  _$ReactionResultCopyWithImpl(this._self, this._then);

  final ReactionResult _self;
  final $Res Function(ReactionResult) _then;

/// Create a copy of ReactionResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? reactionCount = null,Object? myReaction = freezed,}) {
  return _then(ReactionResult(
reactionCount: null == reactionCount ? _self.reactionCount : reactionCount // ignore: cast_nullable_to_non_nullable
as int,myReaction: freezed == myReaction ? _self.myReaction : myReaction // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ReactionResult].
extension ReactionResultPatterns on ReactionResult {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReactionResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReactionResult() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReactionResult value)  $default,){
final _that = this;
switch (_that) {
case _ReactionResult():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReactionResult value)?  $default,){
final _that = this;
switch (_that) {
case _ReactionResult() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int reactionCount,  String? myReaction)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReactionResult() when $default != null:
return $default(_that.reactionCount,_that.myReaction);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int reactionCount,  String? myReaction)  $default,) {final _that = this;
switch (_that) {
case _ReactionResult():
return $default(_that.reactionCount,_that.myReaction);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int reactionCount,  String? myReaction)?  $default,) {final _that = this;
switch (_that) {
case _ReactionResult() when $default != null:
return $default(_that.reactionCount,_that.myReaction);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReactionResult implements ReactionResult {
  const _ReactionResult({required this.reactionCount, this.myReaction});
  factory _ReactionResult.fromJson(Map<String, dynamic> json) => _$ReactionResultFromJson(json);

@override final  int reactionCount;
@override final  String? myReaction;

/// Create a copy of ReactionResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReactionResultCopyWith<_ReactionResult> get copyWith => __$ReactionResultCopyWithImpl<_ReactionResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReactionResultToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReactionResult&&(identical(other.reactionCount, reactionCount) || other.reactionCount == reactionCount)&&(identical(other.myReaction, myReaction) || other.myReaction == myReaction));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,reactionCount,myReaction);
}

@override
String toString() {
    return 'ReactionResult(reactionCount: $reactionCount, myReaction: $myReaction)';
}


}

/// @nodoc
abstract mixin class _$ReactionResultCopyWith<$Res> implements $ReactionResultCopyWith<$Res> {
  factory _$ReactionResultCopyWith(_ReactionResult value, $Res Function(_ReactionResult) _then) = __$ReactionResultCopyWithImpl;
@override @useResult
$Res call({
 int reactionCount, String? myReaction
});




}
/// @nodoc
class __$ReactionResultCopyWithImpl<$Res>
    implements _$ReactionResultCopyWith<$Res> {
  __$ReactionResultCopyWithImpl(this._self, this._then);

  final _ReactionResult _self;
  final $Res Function(_ReactionResult) _then;

/// Create a copy of ReactionResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? reactionCount = null,Object? myReaction = freezed,}) {
  return _then(_ReactionResult(
reactionCount: null == reactionCount ? _self.reactionCount : reactionCount // ignore: cast_nullable_to_non_nullable
as int,myReaction: freezed == myReaction ? _self.myReaction : myReaction // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
