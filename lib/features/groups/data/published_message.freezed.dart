// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'published_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DisplaySender {

 String get id; String get name;
/// Create a copy of DisplaySender
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DisplaySenderCopyWith<DisplaySender> get copyWith => _$DisplaySenderCopyWithImpl<DisplaySender>(this as DisplaySender, _$identity);

  /// Serializes this DisplaySender to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DisplaySender;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DisplaySender&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DisplaySender;
  return Object.hash(runtimeType,_this.id,_this.name);
}

@override
String toString() {
  final _this = this as DisplaySender;
  return 'DisplaySender(id: ${_this.id}, name: ${_this.name})';
}


}

/// @nodoc
abstract mixin class $DisplaySenderCopyWith<$Res>  {
  factory $DisplaySenderCopyWith(DisplaySender value, $Res Function(DisplaySender) _then) = _$DisplaySenderCopyWithImpl;
@useResult
$Res call({
 String id, String name
});




}
/// @nodoc
class _$DisplaySenderCopyWithImpl<$Res>
    implements $DisplaySenderCopyWith<$Res> {
  _$DisplaySenderCopyWithImpl(this._self, this._then);

  final DisplaySender _self;
  final $Res Function(DisplaySender) _then;

/// Create a copy of DisplaySender
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,}) {
  return _then(DisplaySender(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [DisplaySender].
extension DisplaySenderPatterns on DisplaySender {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DisplaySender value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DisplaySender() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DisplaySender value)  $default,){
final _that = this;
switch (_that) {
case _DisplaySender():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DisplaySender value)?  $default,){
final _that = this;
switch (_that) {
case _DisplaySender() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DisplaySender() when $default != null:
return $default(_that.id,_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name)  $default,) {final _that = this;
switch (_that) {
case _DisplaySender():
return $default(_that.id,_that.name);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name)?  $default,) {final _that = this;
switch (_that) {
case _DisplaySender() when $default != null:
return $default(_that.id,_that.name);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DisplaySender implements DisplaySender {
  const _DisplaySender({required this.id, required this.name});
  factory _DisplaySender.fromJson(Map<String, dynamic> json) => _$DisplaySenderFromJson(json);

@override final  String id;
@override final  String name;

/// Create a copy of DisplaySender
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DisplaySenderCopyWith<_DisplaySender> get copyWith => __$DisplaySenderCopyWithImpl<_DisplaySender>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DisplaySenderToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DisplaySender&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name);
}

@override
String toString() {
    return 'DisplaySender(id: $id, name: $name)';
}


}

/// @nodoc
abstract mixin class _$DisplaySenderCopyWith<$Res> implements $DisplaySenderCopyWith<$Res> {
  factory _$DisplaySenderCopyWith(_DisplaySender value, $Res Function(_DisplaySender) _then) = __$DisplaySenderCopyWithImpl;
@override @useResult
$Res call({
 String id, String name
});




}
/// @nodoc
class __$DisplaySenderCopyWithImpl<$Res>
    implements _$DisplaySenderCopyWith<$Res> {
  __$DisplaySenderCopyWithImpl(this._self, this._then);

  final _DisplaySender _self;
  final $Res Function(_DisplaySender) _then;

/// Create a copy of DisplaySender
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,}) {
  return _then(_DisplaySender(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$PublishedMessage {

 String get id; String get groupId; String get text; DisplaySender? get displaySender;/// An image sent with the message (API.md 49), served to group members.
 String? get attachmentId; DateTime get publishedAt;
/// Create a copy of PublishedMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PublishedMessageCopyWith<PublishedMessage> get copyWith => _$PublishedMessageCopyWithImpl<PublishedMessage>(this as PublishedMessage, _$identity);

  /// Serializes this PublishedMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PublishedMessage;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PublishedMessage&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.groupId, _this.groupId) || other.groupId == _this.groupId)&&(identical(other.text, _this.text) || other.text == _this.text)&&(identical(other.displaySender, _this.displaySender) || other.displaySender == _this.displaySender)&&(identical(other.attachmentId, _this.attachmentId) || other.attachmentId == _this.attachmentId)&&(identical(other.publishedAt, _this.publishedAt) || other.publishedAt == _this.publishedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PublishedMessage;
  return Object.hash(runtimeType,_this.id,_this.groupId,_this.text,_this.displaySender,_this.attachmentId,_this.publishedAt);
}

@override
String toString() {
  final _this = this as PublishedMessage;
  return 'PublishedMessage(id: ${_this.id}, groupId: ${_this.groupId}, text: ${_this.text}, displaySender: ${_this.displaySender}, attachmentId: ${_this.attachmentId}, publishedAt: ${_this.publishedAt})';
}


}

/// @nodoc
abstract mixin class $PublishedMessageCopyWith<$Res>  {
  factory $PublishedMessageCopyWith(PublishedMessage value, $Res Function(PublishedMessage) _then) = _$PublishedMessageCopyWithImpl;
@useResult
$Res call({
 String id, String groupId, String text, DisplaySender? displaySender, String? attachmentId, DateTime publishedAt
});


$DisplaySenderCopyWith<$Res>? get displaySender;

}
/// @nodoc
class _$PublishedMessageCopyWithImpl<$Res>
    implements $PublishedMessageCopyWith<$Res> {
  _$PublishedMessageCopyWithImpl(this._self, this._then);

  final PublishedMessage _self;
  final $Res Function(PublishedMessage) _then;

/// Create a copy of PublishedMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? groupId = null,Object? text = null,Object? displaySender = freezed,Object? attachmentId = freezed,Object? publishedAt = null,}) {
  return _then(PublishedMessage(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,displaySender: freezed == displaySender ? _self.displaySender : displaySender // ignore: cast_nullable_to_non_nullable
as DisplaySender?,attachmentId: freezed == attachmentId ? _self.attachmentId : attachmentId // ignore: cast_nullable_to_non_nullable
as String?,publishedAt: null == publishedAt ? _self.publishedAt : publishedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}
/// Create a copy of PublishedMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DisplaySenderCopyWith<$Res>? get displaySender {
    if (_self.displaySender == null) {
    return null;
  }

  return $DisplaySenderCopyWith<$Res>(_self.displaySender!, (value) {
    return _then(_self.copyWith(displaySender: value));
  });
}
}


/// Adds pattern-matching-related methods to [PublishedMessage].
extension PublishedMessagePatterns on PublishedMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PublishedMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PublishedMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PublishedMessage value)  $default,){
final _that = this;
switch (_that) {
case _PublishedMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PublishedMessage value)?  $default,){
final _that = this;
switch (_that) {
case _PublishedMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String groupId,  String text,  DisplaySender? displaySender,  String? attachmentId,  DateTime publishedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PublishedMessage() when $default != null:
return $default(_that.id,_that.groupId,_that.text,_that.displaySender,_that.attachmentId,_that.publishedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String groupId,  String text,  DisplaySender? displaySender,  String? attachmentId,  DateTime publishedAt)  $default,) {final _that = this;
switch (_that) {
case _PublishedMessage():
return $default(_that.id,_that.groupId,_that.text,_that.displaySender,_that.attachmentId,_that.publishedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String groupId,  String text,  DisplaySender? displaySender,  String? attachmentId,  DateTime publishedAt)?  $default,) {final _that = this;
switch (_that) {
case _PublishedMessage() when $default != null:
return $default(_that.id,_that.groupId,_that.text,_that.displaySender,_that.attachmentId,_that.publishedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PublishedMessage implements PublishedMessage {
  const _PublishedMessage({required this.id, required this.groupId, required this.text, this.displaySender, this.attachmentId, required this.publishedAt});
  factory _PublishedMessage.fromJson(Map<String, dynamic> json) => _$PublishedMessageFromJson(json);

@override final  String id;
@override final  String groupId;
@override final  String text;
@override final  DisplaySender? displaySender;
/// An image sent with the message (API.md 49), served to group members.
@override final  String? attachmentId;
@override final  DateTime publishedAt;

/// Create a copy of PublishedMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PublishedMessageCopyWith<_PublishedMessage> get copyWith => __$PublishedMessageCopyWithImpl<_PublishedMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PublishedMessageToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PublishedMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.text, text) || other.text == text)&&(identical(other.displaySender, displaySender) || other.displaySender == displaySender)&&(identical(other.attachmentId, attachmentId) || other.attachmentId == attachmentId)&&(identical(other.publishedAt, publishedAt) || other.publishedAt == publishedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,groupId,text,displaySender,attachmentId,publishedAt);
}

@override
String toString() {
    return 'PublishedMessage(id: $id, groupId: $groupId, text: $text, displaySender: $displaySender, attachmentId: $attachmentId, publishedAt: $publishedAt)';
}


}

/// @nodoc
abstract mixin class _$PublishedMessageCopyWith<$Res> implements $PublishedMessageCopyWith<$Res> {
  factory _$PublishedMessageCopyWith(_PublishedMessage value, $Res Function(_PublishedMessage) _then) = __$PublishedMessageCopyWithImpl;
@override @useResult
$Res call({
 String id, String groupId, String text, DisplaySender? displaySender, String? attachmentId, DateTime publishedAt
});


@override $DisplaySenderCopyWith<$Res>? get displaySender;

}
/// @nodoc
class __$PublishedMessageCopyWithImpl<$Res>
    implements _$PublishedMessageCopyWith<$Res> {
  __$PublishedMessageCopyWithImpl(this._self, this._then);

  final _PublishedMessage _self;
  final $Res Function(_PublishedMessage) _then;

/// Create a copy of PublishedMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? groupId = null,Object? text = null,Object? displaySender = freezed,Object? attachmentId = freezed,Object? publishedAt = null,}) {
  return _then(_PublishedMessage(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,displaySender: freezed == displaySender ? _self.displaySender : displaySender // ignore: cast_nullable_to_non_nullable
as DisplaySender?,attachmentId: freezed == attachmentId ? _self.attachmentId : attachmentId // ignore: cast_nullable_to_non_nullable
as String?,publishedAt: null == publishedAt ? _self.publishedAt : publishedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

/// Create a copy of PublishedMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DisplaySenderCopyWith<$Res>? get displaySender {
    if (_self.displaySender == null) {
    return null;
  }

  return $DisplaySenderCopyWith<$Res>(_self.displaySender!, (value) {
    return _then(_self.copyWith(displaySender: value));
  });
}
}

// dart format on
