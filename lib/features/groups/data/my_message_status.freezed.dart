// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'my_message_status.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MyMessageStatus {

 String get id; String get groupId;@JsonKey(unknownEnumValue: MessageStatus.pending) MessageStatus get status; bool get isAnonymous; DateTime get createdAt;
/// Create a copy of MyMessageStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MyMessageStatusCopyWith<MyMessageStatus> get copyWith => _$MyMessageStatusCopyWithImpl<MyMessageStatus>(this as MyMessageStatus, _$identity);

  /// Serializes this MyMessageStatus to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MyMessageStatus;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MyMessageStatus&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.groupId, _this.groupId) || other.groupId == _this.groupId)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.isAnonymous, _this.isAnonymous) || other.isAnonymous == _this.isAnonymous)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MyMessageStatus;
  return Object.hash(runtimeType,_this.id,_this.groupId,_this.status,_this.isAnonymous,_this.createdAt);
}

@override
String toString() {
  final _this = this as MyMessageStatus;
  return 'MyMessageStatus(id: ${_this.id}, groupId: ${_this.groupId}, status: ${_this.status}, isAnonymous: ${_this.isAnonymous}, createdAt: ${_this.createdAt})';
}


}

/// @nodoc
abstract mixin class $MyMessageStatusCopyWith<$Res>  {
  factory $MyMessageStatusCopyWith(MyMessageStatus value, $Res Function(MyMessageStatus) _then) = _$MyMessageStatusCopyWithImpl;
@useResult
$Res call({
 String id, String groupId,@JsonKey(unknownEnumValue: MessageStatus.pending) MessageStatus status, bool isAnonymous, DateTime createdAt
});




}
/// @nodoc
class _$MyMessageStatusCopyWithImpl<$Res>
    implements $MyMessageStatusCopyWith<$Res> {
  _$MyMessageStatusCopyWithImpl(this._self, this._then);

  final MyMessageStatus _self;
  final $Res Function(MyMessageStatus) _then;

/// Create a copy of MyMessageStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? groupId = null,Object? status = null,Object? isAnonymous = null,Object? createdAt = null,}) {
  return _then(MyMessageStatus(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MessageStatus,isAnonymous: null == isAnonymous ? _self.isAnonymous : isAnonymous // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [MyMessageStatus].
extension MyMessageStatusPatterns on MyMessageStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MyMessageStatus value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MyMessageStatus() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MyMessageStatus value)  $default,){
final _that = this;
switch (_that) {
case _MyMessageStatus():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MyMessageStatus value)?  $default,){
final _that = this;
switch (_that) {
case _MyMessageStatus() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String groupId, @JsonKey(unknownEnumValue: MessageStatus.pending)  MessageStatus status,  bool isAnonymous,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MyMessageStatus() when $default != null:
return $default(_that.id,_that.groupId,_that.status,_that.isAnonymous,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String groupId, @JsonKey(unknownEnumValue: MessageStatus.pending)  MessageStatus status,  bool isAnonymous,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _MyMessageStatus():
return $default(_that.id,_that.groupId,_that.status,_that.isAnonymous,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String groupId, @JsonKey(unknownEnumValue: MessageStatus.pending)  MessageStatus status,  bool isAnonymous,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _MyMessageStatus() when $default != null:
return $default(_that.id,_that.groupId,_that.status,_that.isAnonymous,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MyMessageStatus implements MyMessageStatus {
  const _MyMessageStatus({required this.id, required this.groupId, @JsonKey(unknownEnumValue: MessageStatus.pending) required this.status, required this.isAnonymous, required this.createdAt});
  factory _MyMessageStatus.fromJson(Map<String, dynamic> json) => _$MyMessageStatusFromJson(json);

@override final  String id;
@override final  String groupId;
@override@JsonKey(unknownEnumValue: MessageStatus.pending) final  MessageStatus status;
@override final  bool isAnonymous;
@override final  DateTime createdAt;

/// Create a copy of MyMessageStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MyMessageStatusCopyWith<_MyMessageStatus> get copyWith => __$MyMessageStatusCopyWithImpl<_MyMessageStatus>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MyMessageStatusToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MyMessageStatus&&(identical(other.id, id) || other.id == id)&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.status, status) || other.status == status)&&(identical(other.isAnonymous, isAnonymous) || other.isAnonymous == isAnonymous)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,groupId,status,isAnonymous,createdAt);
}

@override
String toString() {
    return 'MyMessageStatus(id: $id, groupId: $groupId, status: $status, isAnonymous: $isAnonymous, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$MyMessageStatusCopyWith<$Res> implements $MyMessageStatusCopyWith<$Res> {
  factory _$MyMessageStatusCopyWith(_MyMessageStatus value, $Res Function(_MyMessageStatus) _then) = __$MyMessageStatusCopyWithImpl;
@override @useResult
$Res call({
 String id, String groupId,@JsonKey(unknownEnumValue: MessageStatus.pending) MessageStatus status, bool isAnonymous, DateTime createdAt
});




}
/// @nodoc
class __$MyMessageStatusCopyWithImpl<$Res>
    implements _$MyMessageStatusCopyWith<$Res> {
  __$MyMessageStatusCopyWithImpl(this._self, this._then);

  final _MyMessageStatus _self;
  final $Res Function(_MyMessageStatus) _then;

/// Create a copy of MyMessageStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? groupId = null,Object? status = null,Object? isAnonymous = null,Object? createdAt = null,}) {
  return _then(_MyMessageStatus(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MessageStatus,isAnonymous: null == isAnonymous ? _self.isAnonymous : isAnonymous // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
