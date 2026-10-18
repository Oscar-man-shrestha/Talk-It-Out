// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_notification.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$NotificationGroup {

 String get id; String get agenda;
/// Create a copy of NotificationGroup
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationGroupCopyWith<NotificationGroup> get copyWith => _$NotificationGroupCopyWithImpl<NotificationGroup>(this as NotificationGroup, _$identity);

  /// Serializes this NotificationGroup to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as NotificationGroup;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationGroup&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.agenda, _this.agenda) || other.agenda == _this.agenda));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as NotificationGroup;
  return Object.hash(runtimeType,_this.id,_this.agenda);
}

@override
String toString() {
  final _this = this as NotificationGroup;
  return 'NotificationGroup(id: ${_this.id}, agenda: ${_this.agenda})';
}


}

/// @nodoc
abstract mixin class $NotificationGroupCopyWith<$Res>  {
  factory $NotificationGroupCopyWith(NotificationGroup value, $Res Function(NotificationGroup) _then) = _$NotificationGroupCopyWithImpl;
@useResult
$Res call({
 String id, String agenda
});




}
/// @nodoc
class _$NotificationGroupCopyWithImpl<$Res>
    implements $NotificationGroupCopyWith<$Res> {
  _$NotificationGroupCopyWithImpl(this._self, this._then);

  final NotificationGroup _self;
  final $Res Function(NotificationGroup) _then;

/// Create a copy of NotificationGroup
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? agenda = null,}) {
  return _then(NotificationGroup(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agenda: null == agenda ? _self.agenda : agenda // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [NotificationGroup].
extension NotificationGroupPatterns on NotificationGroup {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NotificationGroup value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NotificationGroup() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NotificationGroup value)  $default,){
final _that = this;
switch (_that) {
case _NotificationGroup():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NotificationGroup value)?  $default,){
final _that = this;
switch (_that) {
case _NotificationGroup() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String agenda)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NotificationGroup() when $default != null:
return $default(_that.id,_that.agenda);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String agenda)  $default,) {final _that = this;
switch (_that) {
case _NotificationGroup():
return $default(_that.id,_that.agenda);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String agenda)?  $default,) {final _that = this;
switch (_that) {
case _NotificationGroup() when $default != null:
return $default(_that.id,_that.agenda);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NotificationGroup implements NotificationGroup {
  const _NotificationGroup({required this.id, required this.agenda});
  factory _NotificationGroup.fromJson(Map<String, dynamic> json) => _$NotificationGroupFromJson(json);

@override final  String id;
@override final  String agenda;

/// Create a copy of NotificationGroup
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NotificationGroupCopyWith<_NotificationGroup> get copyWith => __$NotificationGroupCopyWithImpl<_NotificationGroup>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NotificationGroupToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _NotificationGroup&&(identical(other.id, id) || other.id == id)&&(identical(other.agenda, agenda) || other.agenda == agenda));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,agenda);
}

@override
String toString() {
    return 'NotificationGroup(id: $id, agenda: $agenda)';
}


}

/// @nodoc
abstract mixin class _$NotificationGroupCopyWith<$Res> implements $NotificationGroupCopyWith<$Res> {
  factory _$NotificationGroupCopyWith(_NotificationGroup value, $Res Function(_NotificationGroup) _then) = __$NotificationGroupCopyWithImpl;
@override @useResult
$Res call({
 String id, String agenda
});




}
/// @nodoc
class __$NotificationGroupCopyWithImpl<$Res>
    implements _$NotificationGroupCopyWith<$Res> {
  __$NotificationGroupCopyWithImpl(this._self, this._then);

  final _NotificationGroup _self;
  final $Res Function(_NotificationGroup) _then;

/// Create a copy of NotificationGroup
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? agenda = null,}) {
  return _then(_NotificationGroup(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agenda: null == agenda ? _self.agenda : agenda // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$AppNotification {

 String get id;@JsonKey(unknownEnumValue: NotificationType.unknown) NotificationType get type; String get refId; NotificationGroup get group; DateTime get createdAt; DateTime? get readAt;
/// Create a copy of AppNotification
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppNotificationCopyWith<AppNotification> get copyWith => _$AppNotificationCopyWithImpl<AppNotification>(this as AppNotification, _$identity);

  /// Serializes this AppNotification to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AppNotification;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppNotification&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.refId, _this.refId) || other.refId == _this.refId)&&(identical(other.group, _this.group) || other.group == _this.group)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.readAt, _this.readAt) || other.readAt == _this.readAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AppNotification;
  return Object.hash(runtimeType,_this.id,_this.type,_this.refId,_this.group,_this.createdAt,_this.readAt);
}

@override
String toString() {
  final _this = this as AppNotification;
  return 'AppNotification(id: ${_this.id}, type: ${_this.type}, refId: ${_this.refId}, group: ${_this.group}, createdAt: ${_this.createdAt}, readAt: ${_this.readAt})';
}


}

/// @nodoc
abstract mixin class $AppNotificationCopyWith<$Res>  {
  factory $AppNotificationCopyWith(AppNotification value, $Res Function(AppNotification) _then) = _$AppNotificationCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(unknownEnumValue: NotificationType.unknown) NotificationType type, String refId, NotificationGroup group, DateTime createdAt, DateTime? readAt
});


$NotificationGroupCopyWith<$Res> get group;

}
/// @nodoc
class _$AppNotificationCopyWithImpl<$Res>
    implements $AppNotificationCopyWith<$Res> {
  _$AppNotificationCopyWithImpl(this._self, this._then);

  final AppNotification _self;
  final $Res Function(AppNotification) _then;

/// Create a copy of AppNotification
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? type = null,Object? refId = null,Object? group = null,Object? createdAt = null,Object? readAt = freezed,}) {
  return _then(AppNotification(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as NotificationType,refId: null == refId ? _self.refId : refId // ignore: cast_nullable_to_non_nullable
as String,group: null == group ? _self.group : group // ignore: cast_nullable_to_non_nullable
as NotificationGroup,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,readAt: freezed == readAt ? _self.readAt : readAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}
/// Create a copy of AppNotification
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NotificationGroupCopyWith<$Res> get group {
  
  return $NotificationGroupCopyWith<$Res>(_self.group, (value) {
    return _then(_self.copyWith(group: value));
  });
}
}


/// Adds pattern-matching-related methods to [AppNotification].
extension AppNotificationPatterns on AppNotification {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppNotification value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppNotification() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppNotification value)  $default,){
final _that = this;
switch (_that) {
case _AppNotification():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppNotification value)?  $default,){
final _that = this;
switch (_that) {
case _AppNotification() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(unknownEnumValue: NotificationType.unknown)  NotificationType type,  String refId,  NotificationGroup group,  DateTime createdAt,  DateTime? readAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppNotification() when $default != null:
return $default(_that.id,_that.type,_that.refId,_that.group,_that.createdAt,_that.readAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(unknownEnumValue: NotificationType.unknown)  NotificationType type,  String refId,  NotificationGroup group,  DateTime createdAt,  DateTime? readAt)  $default,) {final _that = this;
switch (_that) {
case _AppNotification():
return $default(_that.id,_that.type,_that.refId,_that.group,_that.createdAt,_that.readAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(unknownEnumValue: NotificationType.unknown)  NotificationType type,  String refId,  NotificationGroup group,  DateTime createdAt,  DateTime? readAt)?  $default,) {final _that = this;
switch (_that) {
case _AppNotification() when $default != null:
return $default(_that.id,_that.type,_that.refId,_that.group,_that.createdAt,_that.readAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AppNotification extends AppNotification {
  const _AppNotification({required this.id, @JsonKey(unknownEnumValue: NotificationType.unknown) required this.type, required this.refId, required this.group, required this.createdAt, this.readAt}): super._();
  factory _AppNotification.fromJson(Map<String, dynamic> json) => _$AppNotificationFromJson(json);

@override final  String id;
@override@JsonKey(unknownEnumValue: NotificationType.unknown) final  NotificationType type;
@override final  String refId;
@override final  NotificationGroup group;
@override final  DateTime createdAt;
@override final  DateTime? readAt;

/// Create a copy of AppNotification
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppNotificationCopyWith<_AppNotification> get copyWith => __$AppNotificationCopyWithImpl<_AppNotification>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AppNotificationToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppNotification&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.refId, refId) || other.refId == refId)&&(identical(other.group, group) || other.group == group)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.readAt, readAt) || other.readAt == readAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,type,refId,group,createdAt,readAt);
}

@override
String toString() {
    return 'AppNotification(id: $id, type: $type, refId: $refId, group: $group, createdAt: $createdAt, readAt: $readAt)';
}


}

/// @nodoc
abstract mixin class _$AppNotificationCopyWith<$Res> implements $AppNotificationCopyWith<$Res> {
  factory _$AppNotificationCopyWith(_AppNotification value, $Res Function(_AppNotification) _then) = __$AppNotificationCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(unknownEnumValue: NotificationType.unknown) NotificationType type, String refId, NotificationGroup group, DateTime createdAt, DateTime? readAt
});


@override $NotificationGroupCopyWith<$Res> get group;

}
/// @nodoc
class __$AppNotificationCopyWithImpl<$Res>
    implements _$AppNotificationCopyWith<$Res> {
  __$AppNotificationCopyWithImpl(this._self, this._then);

  final _AppNotification _self;
  final $Res Function(_AppNotification) _then;

/// Create a copy of AppNotification
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? type = null,Object? refId = null,Object? group = null,Object? createdAt = null,Object? readAt = freezed,}) {
  return _then(_AppNotification(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as NotificationType,refId: null == refId ? _self.refId : refId // ignore: cast_nullable_to_non_nullable
as String,group: null == group ? _self.group : group // ignore: cast_nullable_to_non_nullable
as NotificationGroup,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,readAt: freezed == readAt ? _self.readAt : readAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

/// Create a copy of AppNotification
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NotificationGroupCopyWith<$Res> get group {
  
  return $NotificationGroupCopyWith<$Res>(_self.group, (value) {
    return _then(_self.copyWith(group: value));
  });
}
}

// dart format on
