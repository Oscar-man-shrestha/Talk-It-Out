// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'group.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Group {

 String get id; String get agenda; String get controllerId; String? get sourcePostId; DateTime get createdAt;@JsonKey(unknownEnumValue: GroupRole.contributor) GroupRole get myRole; int? get pendingCount;/// Group info set by the controller (`API.md` 67).
 String get description; String get rules; int get memberCount;/// Your own settings for this group: muted groups do not count toward
/// the Groups badge; pinned groups stay at the top.
 bool get muted; bool get pinned;
/// Create a copy of Group
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GroupCopyWith<Group> get copyWith => _$GroupCopyWithImpl<Group>(this as Group, _$identity);

  /// Serializes this Group to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Group;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Group&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.agenda, _this.agenda) || other.agenda == _this.agenda)&&(identical(other.controllerId, _this.controllerId) || other.controllerId == _this.controllerId)&&(identical(other.sourcePostId, _this.sourcePostId) || other.sourcePostId == _this.sourcePostId)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.myRole, _this.myRole) || other.myRole == _this.myRole)&&(identical(other.pendingCount, _this.pendingCount) || other.pendingCount == _this.pendingCount)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.rules, _this.rules) || other.rules == _this.rules)&&(identical(other.memberCount, _this.memberCount) || other.memberCount == _this.memberCount)&&(identical(other.muted, _this.muted) || other.muted == _this.muted)&&(identical(other.pinned, _this.pinned) || other.pinned == _this.pinned));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Group;
  return Object.hash(runtimeType,_this.id,_this.agenda,_this.controllerId,_this.sourcePostId,_this.createdAt,_this.myRole,_this.pendingCount,_this.description,_this.rules,_this.memberCount,_this.muted,_this.pinned);
}

@override
String toString() {
  final _this = this as Group;
  return 'Group(id: ${_this.id}, agenda: ${_this.agenda}, controllerId: ${_this.controllerId}, sourcePostId: ${_this.sourcePostId}, createdAt: ${_this.createdAt}, myRole: ${_this.myRole}, pendingCount: ${_this.pendingCount}, description: ${_this.description}, rules: ${_this.rules}, memberCount: ${_this.memberCount}, muted: ${_this.muted}, pinned: ${_this.pinned})';
}


}

/// @nodoc
abstract mixin class $GroupCopyWith<$Res>  {
  factory $GroupCopyWith(Group value, $Res Function(Group) _then) = _$GroupCopyWithImpl;
@useResult
$Res call({
 String id, String agenda, String controllerId, String? sourcePostId, DateTime createdAt,@JsonKey(unknownEnumValue: GroupRole.contributor) GroupRole myRole, int? pendingCount, String description, String rules, int memberCount, bool muted, bool pinned
});




}
/// @nodoc
class _$GroupCopyWithImpl<$Res>
    implements $GroupCopyWith<$Res> {
  _$GroupCopyWithImpl(this._self, this._then);

  final Group _self;
  final $Res Function(Group) _then;

/// Create a copy of Group
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? agenda = null,Object? controllerId = null,Object? sourcePostId = freezed,Object? createdAt = null,Object? myRole = null,Object? pendingCount = freezed,Object? description = null,Object? rules = null,Object? memberCount = null,Object? muted = null,Object? pinned = null,}) {
  return _then(Group(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agenda: null == agenda ? _self.agenda : agenda // ignore: cast_nullable_to_non_nullable
as String,controllerId: null == controllerId ? _self.controllerId : controllerId // ignore: cast_nullable_to_non_nullable
as String,sourcePostId: freezed == sourcePostId ? _self.sourcePostId : sourcePostId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,myRole: null == myRole ? _self.myRole : myRole // ignore: cast_nullable_to_non_nullable
as GroupRole,pendingCount: freezed == pendingCount ? _self.pendingCount : pendingCount // ignore: cast_nullable_to_non_nullable
as int?,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,rules: null == rules ? _self.rules : rules // ignore: cast_nullable_to_non_nullable
as String,memberCount: null == memberCount ? _self.memberCount : memberCount // ignore: cast_nullable_to_non_nullable
as int,muted: null == muted ? _self.muted : muted // ignore: cast_nullable_to_non_nullable
as bool,pinned: null == pinned ? _self.pinned : pinned // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Group].
extension GroupPatterns on Group {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Group value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Group() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Group value)  $default,){
final _that = this;
switch (_that) {
case _Group():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Group value)?  $default,){
final _that = this;
switch (_that) {
case _Group() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String agenda,  String controllerId,  String? sourcePostId,  DateTime createdAt, @JsonKey(unknownEnumValue: GroupRole.contributor)  GroupRole myRole,  int? pendingCount,  String description,  String rules,  int memberCount,  bool muted,  bool pinned)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Group() when $default != null:
return $default(_that.id,_that.agenda,_that.controllerId,_that.sourcePostId,_that.createdAt,_that.myRole,_that.pendingCount,_that.description,_that.rules,_that.memberCount,_that.muted,_that.pinned);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String agenda,  String controllerId,  String? sourcePostId,  DateTime createdAt, @JsonKey(unknownEnumValue: GroupRole.contributor)  GroupRole myRole,  int? pendingCount,  String description,  String rules,  int memberCount,  bool muted,  bool pinned)  $default,) {final _that = this;
switch (_that) {
case _Group():
return $default(_that.id,_that.agenda,_that.controllerId,_that.sourcePostId,_that.createdAt,_that.myRole,_that.pendingCount,_that.description,_that.rules,_that.memberCount,_that.muted,_that.pinned);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String agenda,  String controllerId,  String? sourcePostId,  DateTime createdAt, @JsonKey(unknownEnumValue: GroupRole.contributor)  GroupRole myRole,  int? pendingCount,  String description,  String rules,  int memberCount,  bool muted,  bool pinned)?  $default,) {final _that = this;
switch (_that) {
case _Group() when $default != null:
return $default(_that.id,_that.agenda,_that.controllerId,_that.sourcePostId,_that.createdAt,_that.myRole,_that.pendingCount,_that.description,_that.rules,_that.memberCount,_that.muted,_that.pinned);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Group implements Group {
  const _Group({required this.id, required this.agenda, required this.controllerId, this.sourcePostId, required this.createdAt, @JsonKey(unknownEnumValue: GroupRole.contributor) required this.myRole, this.pendingCount, this.description = '', this.rules = '', this.memberCount = 0, this.muted = false, this.pinned = false});
  factory _Group.fromJson(Map<String, dynamic> json) => _$GroupFromJson(json);

@override final  String id;
@override final  String agenda;
@override final  String controllerId;
@override final  String? sourcePostId;
@override final  DateTime createdAt;
@override@JsonKey(unknownEnumValue: GroupRole.contributor) final  GroupRole myRole;
@override final  int? pendingCount;
/// Group info set by the controller (`API.md` 67).
@override@JsonKey() final  String description;
@override@JsonKey() final  String rules;
@override@JsonKey() final  int memberCount;
/// Your own settings for this group: muted groups do not count toward
/// the Groups badge; pinned groups stay at the top.
@override@JsonKey() final  bool muted;
@override@JsonKey() final  bool pinned;

/// Create a copy of Group
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GroupCopyWith<_Group> get copyWith => __$GroupCopyWithImpl<_Group>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GroupToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Group&&(identical(other.id, id) || other.id == id)&&(identical(other.agenda, agenda) || other.agenda == agenda)&&(identical(other.controllerId, controllerId) || other.controllerId == controllerId)&&(identical(other.sourcePostId, sourcePostId) || other.sourcePostId == sourcePostId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.myRole, myRole) || other.myRole == myRole)&&(identical(other.pendingCount, pendingCount) || other.pendingCount == pendingCount)&&(identical(other.description, description) || other.description == description)&&(identical(other.rules, rules) || other.rules == rules)&&(identical(other.memberCount, memberCount) || other.memberCount == memberCount)&&(identical(other.muted, muted) || other.muted == muted)&&(identical(other.pinned, pinned) || other.pinned == pinned));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,agenda,controllerId,sourcePostId,createdAt,myRole,pendingCount,description,rules,memberCount,muted,pinned);
}

@override
String toString() {
    return 'Group(id: $id, agenda: $agenda, controllerId: $controllerId, sourcePostId: $sourcePostId, createdAt: $createdAt, myRole: $myRole, pendingCount: $pendingCount, description: $description, rules: $rules, memberCount: $memberCount, muted: $muted, pinned: $pinned)';
}


}

/// @nodoc
abstract mixin class _$GroupCopyWith<$Res> implements $GroupCopyWith<$Res> {
  factory _$GroupCopyWith(_Group value, $Res Function(_Group) _then) = __$GroupCopyWithImpl;
@override @useResult
$Res call({
 String id, String agenda, String controllerId, String? sourcePostId, DateTime createdAt,@JsonKey(unknownEnumValue: GroupRole.contributor) GroupRole myRole, int? pendingCount, String description, String rules, int memberCount, bool muted, bool pinned
});




}
/// @nodoc
class __$GroupCopyWithImpl<$Res>
    implements _$GroupCopyWith<$Res> {
  __$GroupCopyWithImpl(this._self, this._then);

  final _Group _self;
  final $Res Function(_Group) _then;

/// Create a copy of Group
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? agenda = null,Object? controllerId = null,Object? sourcePostId = freezed,Object? createdAt = null,Object? myRole = null,Object? pendingCount = freezed,Object? description = null,Object? rules = null,Object? memberCount = null,Object? muted = null,Object? pinned = null,}) {
  return _then(_Group(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agenda: null == agenda ? _self.agenda : agenda // ignore: cast_nullable_to_non_nullable
as String,controllerId: null == controllerId ? _self.controllerId : controllerId // ignore: cast_nullable_to_non_nullable
as String,sourcePostId: freezed == sourcePostId ? _self.sourcePostId : sourcePostId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,myRole: null == myRole ? _self.myRole : myRole // ignore: cast_nullable_to_non_nullable
as GroupRole,pendingCount: freezed == pendingCount ? _self.pendingCount : pendingCount // ignore: cast_nullable_to_non_nullable
as int?,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,rules: null == rules ? _self.rules : rules // ignore: cast_nullable_to_non_nullable
as String,memberCount: null == memberCount ? _self.memberCount : memberCount // ignore: cast_nullable_to_non_nullable
as int,muted: null == muted ? _self.muted : muted // ignore: cast_nullable_to_non_nullable
as bool,pinned: null == pinned ? _self.pinned : pinned // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
