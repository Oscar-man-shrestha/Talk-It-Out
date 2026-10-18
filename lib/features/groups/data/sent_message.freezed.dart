// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sent_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SentMessage {

 String get id; String get groupId;@JsonKey(unknownEnumValue: MessageStatus.pending) MessageStatus get status; DateTime get createdAt;
/// Create a copy of SentMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SentMessageCopyWith<SentMessage> get copyWith => _$SentMessageCopyWithImpl<SentMessage>(this as SentMessage, _$identity);

  /// Serializes this SentMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SentMessage;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SentMessage&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.groupId, _this.groupId) || other.groupId == _this.groupId)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SentMessage;
  return Object.hash(runtimeType,_this.id,_this.groupId,_this.status,_this.createdAt);
}

@override
String toString() {
  final _this = this as SentMessage;
  return 'SentMessage(id: ${_this.id}, groupId: ${_this.groupId}, status: ${_this.status}, createdAt: ${_this.createdAt})';
}


}

/// @nodoc
abstract mixin class $SentMessageCopyWith<$Res>  {
  factory $SentMessageCopyWith(SentMessage value, $Res Function(SentMessage) _then) = _$SentMessageCopyWithImpl;
@useResult
$Res call({
 String id, String groupId,@JsonKey(unknownEnumValue: MessageStatus.pending) MessageStatus status, DateTime createdAt
});




}
/// @nodoc
class _$SentMessageCopyWithImpl<$Res>
    implements $SentMessageCopyWith<$Res> {
  _$SentMessageCopyWithImpl(this._self, this._then);

  final SentMessage _self;
  final $Res Function(SentMessage) _then;

/// Create a copy of SentMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? groupId = null,Object? status = null,Object? createdAt = null,}) {
  return _then(SentMessage(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MessageStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [SentMessage].
extension SentMessagePatterns on SentMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SentMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SentMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SentMessage value)  $default,){
final _that = this;
switch (_that) {
case _SentMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SentMessage value)?  $default,){
final _that = this;
switch (_that) {
case _SentMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String groupId, @JsonKey(unknownEnumValue: MessageStatus.pending)  MessageStatus status,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SentMessage() when $default != null:
return $default(_that.id,_that.groupId,_that.status,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String groupId, @JsonKey(unknownEnumValue: MessageStatus.pending)  MessageStatus status,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _SentMessage():
return $default(_that.id,_that.groupId,_that.status,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String groupId, @JsonKey(unknownEnumValue: MessageStatus.pending)  MessageStatus status,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _SentMessage() when $default != null:
return $default(_that.id,_that.groupId,_that.status,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SentMessage implements SentMessage {
  const _SentMessage({required this.id, required this.groupId, @JsonKey(unknownEnumValue: MessageStatus.pending) required this.status, required this.createdAt});
  factory _SentMessage.fromJson(Map<String, dynamic> json) => _$SentMessageFromJson(json);

@override final  String id;
@override final  String groupId;
@override@JsonKey(unknownEnumValue: MessageStatus.pending) final  MessageStatus status;
@override final  DateTime createdAt;

/// Create a copy of SentMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SentMessageCopyWith<_SentMessage> get copyWith => __$SentMessageCopyWithImpl<_SentMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SentMessageToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SentMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,groupId,status,createdAt);
}

@override
String toString() {
    return 'SentMessage(id: $id, groupId: $groupId, status: $status, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$SentMessageCopyWith<$Res> implements $SentMessageCopyWith<$Res> {
  factory _$SentMessageCopyWith(_SentMessage value, $Res Function(_SentMessage) _then) = __$SentMessageCopyWithImpl;
@override @useResult
$Res call({
 String id, String groupId,@JsonKey(unknownEnumValue: MessageStatus.pending) MessageStatus status, DateTime createdAt
});




}
/// @nodoc
class __$SentMessageCopyWithImpl<$Res>
    implements _$SentMessageCopyWith<$Res> {
  __$SentMessageCopyWithImpl(this._self, this._then);

  final _SentMessage _self;
  final $Res Function(_SentMessage) _then;

/// Create a copy of SentMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? groupId = null,Object? status = null,Object? createdAt = null,}) {
  return _then(_SentMessage(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MessageStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
