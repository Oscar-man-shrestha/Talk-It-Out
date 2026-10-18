// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'review_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AcceptResult {

 String get id;@JsonKey(unknownEnumValue: MessageStatus.pending) MessageStatus get status; String get publishedMessageId;
/// Create a copy of AcceptResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AcceptResultCopyWith<AcceptResult> get copyWith => _$AcceptResultCopyWithImpl<AcceptResult>(this as AcceptResult, _$identity);

  /// Serializes this AcceptResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AcceptResult;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AcceptResult&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.publishedMessageId, _this.publishedMessageId) || other.publishedMessageId == _this.publishedMessageId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AcceptResult;
  return Object.hash(runtimeType,_this.id,_this.status,_this.publishedMessageId);
}

@override
String toString() {
  final _this = this as AcceptResult;
  return 'AcceptResult(id: ${_this.id}, status: ${_this.status}, publishedMessageId: ${_this.publishedMessageId})';
}


}

/// @nodoc
abstract mixin class $AcceptResultCopyWith<$Res>  {
  factory $AcceptResultCopyWith(AcceptResult value, $Res Function(AcceptResult) _then) = _$AcceptResultCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(unknownEnumValue: MessageStatus.pending) MessageStatus status, String publishedMessageId
});




}
/// @nodoc
class _$AcceptResultCopyWithImpl<$Res>
    implements $AcceptResultCopyWith<$Res> {
  _$AcceptResultCopyWithImpl(this._self, this._then);

  final AcceptResult _self;
  final $Res Function(AcceptResult) _then;

/// Create a copy of AcceptResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? status = null,Object? publishedMessageId = null,}) {
  return _then(AcceptResult(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MessageStatus,publishedMessageId: null == publishedMessageId ? _self.publishedMessageId : publishedMessageId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [AcceptResult].
extension AcceptResultPatterns on AcceptResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AcceptResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AcceptResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AcceptResult value)  $default,){
final _that = this;
switch (_that) {
case _AcceptResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AcceptResult value)?  $default,){
final _that = this;
switch (_that) {
case _AcceptResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(unknownEnumValue: MessageStatus.pending)  MessageStatus status,  String publishedMessageId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AcceptResult() when $default != null:
return $default(_that.id,_that.status,_that.publishedMessageId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(unknownEnumValue: MessageStatus.pending)  MessageStatus status,  String publishedMessageId)  $default,) {final _that = this;
switch (_that) {
case _AcceptResult():
return $default(_that.id,_that.status,_that.publishedMessageId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(unknownEnumValue: MessageStatus.pending)  MessageStatus status,  String publishedMessageId)?  $default,) {final _that = this;
switch (_that) {
case _AcceptResult() when $default != null:
return $default(_that.id,_that.status,_that.publishedMessageId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AcceptResult implements AcceptResult {
  const _AcceptResult({required this.id, @JsonKey(unknownEnumValue: MessageStatus.pending) required this.status, required this.publishedMessageId});
  factory _AcceptResult.fromJson(Map<String, dynamic> json) => _$AcceptResultFromJson(json);

@override final  String id;
@override@JsonKey(unknownEnumValue: MessageStatus.pending) final  MessageStatus status;
@override final  String publishedMessageId;

/// Create a copy of AcceptResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AcceptResultCopyWith<_AcceptResult> get copyWith => __$AcceptResultCopyWithImpl<_AcceptResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AcceptResultToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AcceptResult&&(identical(other.id, id) || other.id == id)&&(identical(other.status, status) || other.status == status)&&(identical(other.publishedMessageId, publishedMessageId) || other.publishedMessageId == publishedMessageId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,status,publishedMessageId);
}

@override
String toString() {
    return 'AcceptResult(id: $id, status: $status, publishedMessageId: $publishedMessageId)';
}


}

/// @nodoc
abstract mixin class _$AcceptResultCopyWith<$Res> implements $AcceptResultCopyWith<$Res> {
  factory _$AcceptResultCopyWith(_AcceptResult value, $Res Function(_AcceptResult) _then) = __$AcceptResultCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(unknownEnumValue: MessageStatus.pending) MessageStatus status, String publishedMessageId
});




}
/// @nodoc
class __$AcceptResultCopyWithImpl<$Res>
    implements _$AcceptResultCopyWith<$Res> {
  __$AcceptResultCopyWithImpl(this._self, this._then);

  final _AcceptResult _self;
  final $Res Function(_AcceptResult) _then;

/// Create a copy of AcceptResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? status = null,Object? publishedMessageId = null,}) {
  return _then(_AcceptResult(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MessageStatus,publishedMessageId: null == publishedMessageId ? _self.publishedMessageId : publishedMessageId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$RejectResult {

 String get id;@JsonKey(unknownEnumValue: MessageStatus.pending) MessageStatus get status;
/// Create a copy of RejectResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RejectResultCopyWith<RejectResult> get copyWith => _$RejectResultCopyWithImpl<RejectResult>(this as RejectResult, _$identity);

  /// Serializes this RejectResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RejectResult;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RejectResult&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.status, _this.status) || other.status == _this.status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RejectResult;
  return Object.hash(runtimeType,_this.id,_this.status);
}

@override
String toString() {
  final _this = this as RejectResult;
  return 'RejectResult(id: ${_this.id}, status: ${_this.status})';
}


}

/// @nodoc
abstract mixin class $RejectResultCopyWith<$Res>  {
  factory $RejectResultCopyWith(RejectResult value, $Res Function(RejectResult) _then) = _$RejectResultCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(unknownEnumValue: MessageStatus.pending) MessageStatus status
});




}
/// @nodoc
class _$RejectResultCopyWithImpl<$Res>
    implements $RejectResultCopyWith<$Res> {
  _$RejectResultCopyWithImpl(this._self, this._then);

  final RejectResult _self;
  final $Res Function(RejectResult) _then;

/// Create a copy of RejectResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? status = null,}) {
  return _then(RejectResult(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MessageStatus,
  ));
}

}


/// Adds pattern-matching-related methods to [RejectResult].
extension RejectResultPatterns on RejectResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RejectResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RejectResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RejectResult value)  $default,){
final _that = this;
switch (_that) {
case _RejectResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RejectResult value)?  $default,){
final _that = this;
switch (_that) {
case _RejectResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(unknownEnumValue: MessageStatus.pending)  MessageStatus status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RejectResult() when $default != null:
return $default(_that.id,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(unknownEnumValue: MessageStatus.pending)  MessageStatus status)  $default,) {final _that = this;
switch (_that) {
case _RejectResult():
return $default(_that.id,_that.status);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(unknownEnumValue: MessageStatus.pending)  MessageStatus status)?  $default,) {final _that = this;
switch (_that) {
case _RejectResult() when $default != null:
return $default(_that.id,_that.status);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RejectResult implements RejectResult {
  const _RejectResult({required this.id, @JsonKey(unknownEnumValue: MessageStatus.pending) required this.status});
  factory _RejectResult.fromJson(Map<String, dynamic> json) => _$RejectResultFromJson(json);

@override final  String id;
@override@JsonKey(unknownEnumValue: MessageStatus.pending) final  MessageStatus status;

/// Create a copy of RejectResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RejectResultCopyWith<_RejectResult> get copyWith => __$RejectResultCopyWithImpl<_RejectResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RejectResultToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RejectResult&&(identical(other.id, id) || other.id == id)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,status);
}

@override
String toString() {
    return 'RejectResult(id: $id, status: $status)';
}


}

/// @nodoc
abstract mixin class _$RejectResultCopyWith<$Res> implements $RejectResultCopyWith<$Res> {
  factory _$RejectResultCopyWith(_RejectResult value, $Res Function(_RejectResult) _then) = __$RejectResultCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(unknownEnumValue: MessageStatus.pending) MessageStatus status
});




}
/// @nodoc
class __$RejectResultCopyWithImpl<$Res>
    implements _$RejectResultCopyWith<$Res> {
  __$RejectResultCopyWithImpl(this._self, this._then);

  final _RejectResult _self;
  final $Res Function(_RejectResult) _then;

/// Create a copy of RejectResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? status = null,}) {
  return _then(_RejectResult(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MessageStatus,
  ));
}


}

// dart format on
