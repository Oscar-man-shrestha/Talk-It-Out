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
mixin _$ReplyQuote {

 String get id; String get text; DisplaySender? get displaySender;
/// Create a copy of ReplyQuote
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReplyQuoteCopyWith<ReplyQuote> get copyWith => _$ReplyQuoteCopyWithImpl<ReplyQuote>(this as ReplyQuote, _$identity);

  /// Serializes this ReplyQuote to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ReplyQuote;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReplyQuote&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.text, _this.text) || other.text == _this.text)&&(identical(other.displaySender, _this.displaySender) || other.displaySender == _this.displaySender));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ReplyQuote;
  return Object.hash(runtimeType,_this.id,_this.text,_this.displaySender);
}

@override
String toString() {
  final _this = this as ReplyQuote;
  return 'ReplyQuote(id: ${_this.id}, text: ${_this.text}, displaySender: ${_this.displaySender})';
}


}

/// @nodoc
abstract mixin class $ReplyQuoteCopyWith<$Res>  {
  factory $ReplyQuoteCopyWith(ReplyQuote value, $Res Function(ReplyQuote) _then) = _$ReplyQuoteCopyWithImpl;
@useResult
$Res call({
 String id, String text, DisplaySender? displaySender
});


$DisplaySenderCopyWith<$Res>? get displaySender;

}
/// @nodoc
class _$ReplyQuoteCopyWithImpl<$Res>
    implements $ReplyQuoteCopyWith<$Res> {
  _$ReplyQuoteCopyWithImpl(this._self, this._then);

  final ReplyQuote _self;
  final $Res Function(ReplyQuote) _then;

/// Create a copy of ReplyQuote
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? text = null,Object? displaySender = freezed,}) {
  return _then(ReplyQuote(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,displaySender: freezed == displaySender ? _self.displaySender : displaySender // ignore: cast_nullable_to_non_nullable
as DisplaySender?,
  ));
}
/// Create a copy of ReplyQuote
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


/// Adds pattern-matching-related methods to [ReplyQuote].
extension ReplyQuotePatterns on ReplyQuote {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReplyQuote value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReplyQuote() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReplyQuote value)  $default,){
final _that = this;
switch (_that) {
case _ReplyQuote():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReplyQuote value)?  $default,){
final _that = this;
switch (_that) {
case _ReplyQuote() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String text,  DisplaySender? displaySender)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReplyQuote() when $default != null:
return $default(_that.id,_that.text,_that.displaySender);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String text,  DisplaySender? displaySender)  $default,) {final _that = this;
switch (_that) {
case _ReplyQuote():
return $default(_that.id,_that.text,_that.displaySender);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String text,  DisplaySender? displaySender)?  $default,) {final _that = this;
switch (_that) {
case _ReplyQuote() when $default != null:
return $default(_that.id,_that.text,_that.displaySender);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReplyQuote implements ReplyQuote {
  const _ReplyQuote({required this.id, required this.text, this.displaySender});
  factory _ReplyQuote.fromJson(Map<String, dynamic> json) => _$ReplyQuoteFromJson(json);

@override final  String id;
@override final  String text;
@override final  DisplaySender? displaySender;

/// Create a copy of ReplyQuote
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReplyQuoteCopyWith<_ReplyQuote> get copyWith => __$ReplyQuoteCopyWithImpl<_ReplyQuote>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReplyQuoteToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReplyQuote&&(identical(other.id, id) || other.id == id)&&(identical(other.text, text) || other.text == text)&&(identical(other.displaySender, displaySender) || other.displaySender == displaySender));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,text,displaySender);
}

@override
String toString() {
    return 'ReplyQuote(id: $id, text: $text, displaySender: $displaySender)';
}


}

/// @nodoc
abstract mixin class _$ReplyQuoteCopyWith<$Res> implements $ReplyQuoteCopyWith<$Res> {
  factory _$ReplyQuoteCopyWith(_ReplyQuote value, $Res Function(_ReplyQuote) _then) = __$ReplyQuoteCopyWithImpl;
@override @useResult
$Res call({
 String id, String text, DisplaySender? displaySender
});


@override $DisplaySenderCopyWith<$Res>? get displaySender;

}
/// @nodoc
class __$ReplyQuoteCopyWithImpl<$Res>
    implements _$ReplyQuoteCopyWith<$Res> {
  __$ReplyQuoteCopyWithImpl(this._self, this._then);

  final _ReplyQuote _self;
  final $Res Function(_ReplyQuote) _then;

/// Create a copy of ReplyQuote
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? text = null,Object? displaySender = freezed,}) {
  return _then(_ReplyQuote(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,displaySender: freezed == displaySender ? _self.displaySender : displaySender // ignore: cast_nullable_to_non_nullable
as DisplaySender?,
  ));
}

/// Create a copy of ReplyQuote
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


/// @nodoc
mixin _$PollOption {

 String get text; int get votes;
/// Create a copy of PollOption
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PollOptionCopyWith<PollOption> get copyWith => _$PollOptionCopyWithImpl<PollOption>(this as PollOption, _$identity);

  /// Serializes this PollOption to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PollOption;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PollOption&&(identical(other.text, _this.text) || other.text == _this.text)&&(identical(other.votes, _this.votes) || other.votes == _this.votes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PollOption;
  return Object.hash(runtimeType,_this.text,_this.votes);
}

@override
String toString() {
  final _this = this as PollOption;
  return 'PollOption(text: ${_this.text}, votes: ${_this.votes})';
}


}

/// @nodoc
abstract mixin class $PollOptionCopyWith<$Res>  {
  factory $PollOptionCopyWith(PollOption value, $Res Function(PollOption) _then) = _$PollOptionCopyWithImpl;
@useResult
$Res call({
 String text, int votes
});




}
/// @nodoc
class _$PollOptionCopyWithImpl<$Res>
    implements $PollOptionCopyWith<$Res> {
  _$PollOptionCopyWithImpl(this._self, this._then);

  final PollOption _self;
  final $Res Function(PollOption) _then;

/// Create a copy of PollOption
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? text = null,Object? votes = null,}) {
  return _then(PollOption(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,votes: null == votes ? _self.votes : votes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [PollOption].
extension PollOptionPatterns on PollOption {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PollOption value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PollOption() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PollOption value)  $default,){
final _that = this;
switch (_that) {
case _PollOption():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PollOption value)?  $default,){
final _that = this;
switch (_that) {
case _PollOption() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String text,  int votes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PollOption() when $default != null:
return $default(_that.text,_that.votes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String text,  int votes)  $default,) {final _that = this;
switch (_that) {
case _PollOption():
return $default(_that.text,_that.votes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String text,  int votes)?  $default,) {final _that = this;
switch (_that) {
case _PollOption() when $default != null:
return $default(_that.text,_that.votes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PollOption implements PollOption {
  const _PollOption({required this.text, this.votes = 0});
  factory _PollOption.fromJson(Map<String, dynamic> json) => _$PollOptionFromJson(json);

@override final  String text;
@override@JsonKey() final  int votes;

/// Create a copy of PollOption
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PollOptionCopyWith<_PollOption> get copyWith => __$PollOptionCopyWithImpl<_PollOption>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PollOptionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PollOption&&(identical(other.text, text) || other.text == text)&&(identical(other.votes, votes) || other.votes == votes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,text,votes);
}

@override
String toString() {
    return 'PollOption(text: $text, votes: $votes)';
}


}

/// @nodoc
abstract mixin class _$PollOptionCopyWith<$Res> implements $PollOptionCopyWith<$Res> {
  factory _$PollOptionCopyWith(_PollOption value, $Res Function(_PollOption) _then) = __$PollOptionCopyWithImpl;
@override @useResult
$Res call({
 String text, int votes
});




}
/// @nodoc
class __$PollOptionCopyWithImpl<$Res>
    implements _$PollOptionCopyWith<$Res> {
  __$PollOptionCopyWithImpl(this._self, this._then);

  final _PollOption _self;
  final $Res Function(_PollOption) _then;

/// Create a copy of PollOption
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? text = null,Object? votes = null,}) {
  return _then(_PollOption(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,votes: null == votes ? _self.votes : votes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$Poll {

 String get id; List<PollOption> get options; int get totalVotes; int? get myVote;
/// Create a copy of Poll
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PollCopyWith<Poll> get copyWith => _$PollCopyWithImpl<Poll>(this as Poll, _$identity);

  /// Serializes this Poll to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Poll;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Poll&&(identical(other.id, _this.id) || other.id == _this.id)&&const DeepCollectionEquality().equals(other.options, _this.options)&&(identical(other.totalVotes, _this.totalVotes) || other.totalVotes == _this.totalVotes)&&(identical(other.myVote, _this.myVote) || other.myVote == _this.myVote));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Poll;
  return Object.hash(runtimeType,_this.id,const DeepCollectionEquality().hash(_this.options),_this.totalVotes,_this.myVote);
}

@override
String toString() {
  final _this = this as Poll;
  return 'Poll(id: ${_this.id}, options: ${_this.options}, totalVotes: ${_this.totalVotes}, myVote: ${_this.myVote})';
}


}

/// @nodoc
abstract mixin class $PollCopyWith<$Res>  {
  factory $PollCopyWith(Poll value, $Res Function(Poll) _then) = _$PollCopyWithImpl;
@useResult
$Res call({
 String id, List<PollOption> options, int totalVotes, int? myVote
});




}
/// @nodoc
class _$PollCopyWithImpl<$Res>
    implements $PollCopyWith<$Res> {
  _$PollCopyWithImpl(this._self, this._then);

  final Poll _self;
  final $Res Function(Poll) _then;

/// Create a copy of Poll
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? options = null,Object? totalVotes = null,Object? myVote = freezed,}) {
  return _then(Poll(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as List<PollOption>,totalVotes: null == totalVotes ? _self.totalVotes : totalVotes // ignore: cast_nullable_to_non_nullable
as int,myVote: freezed == myVote ? _self.myVote : myVote // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [Poll].
extension PollPatterns on Poll {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Poll value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Poll() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Poll value)  $default,){
final _that = this;
switch (_that) {
case _Poll():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Poll value)?  $default,){
final _that = this;
switch (_that) {
case _Poll() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  List<PollOption> options,  int totalVotes,  int? myVote)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Poll() when $default != null:
return $default(_that.id,_that.options,_that.totalVotes,_that.myVote);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  List<PollOption> options,  int totalVotes,  int? myVote)  $default,) {final _that = this;
switch (_that) {
case _Poll():
return $default(_that.id,_that.options,_that.totalVotes,_that.myVote);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  List<PollOption> options,  int totalVotes,  int? myVote)?  $default,) {final _that = this;
switch (_that) {
case _Poll() when $default != null:
return $default(_that.id,_that.options,_that.totalVotes,_that.myVote);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Poll implements Poll {
  const _Poll({required this.id, required  List<PollOption> options, this.totalVotes = 0, this.myVote}): _options = options;
  factory _Poll.fromJson(Map<String, dynamic> json) => _$PollFromJson(json);

@override final  String id;
 final  List<PollOption> _options;
@override List<PollOption> get options {
  if (_options is EqualUnmodifiableListView) return _options;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_options);
}

@override@JsonKey() final  int totalVotes;
@override final  int? myVote;

/// Create a copy of Poll
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PollCopyWith<_Poll> get copyWith => __$PollCopyWithImpl<_Poll>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PollToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Poll&&(identical(other.id, id) || other.id == id)&&const DeepCollectionEquality().equals(other.options, _options)&&(identical(other.totalVotes, totalVotes) || other.totalVotes == totalVotes)&&(identical(other.myVote, myVote) || other.myVote == myVote));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,const DeepCollectionEquality().hash(_options),totalVotes,myVote);
}

@override
String toString() {
    return 'Poll(id: $id, options: $options, totalVotes: $totalVotes, myVote: $myVote)';
}


}

/// @nodoc
abstract mixin class _$PollCopyWith<$Res> implements $PollCopyWith<$Res> {
  factory _$PollCopyWith(_Poll value, $Res Function(_Poll) _then) = __$PollCopyWithImpl;
@override @useResult
$Res call({
 String id, List<PollOption> options, int totalVotes, int? myVote
});




}
/// @nodoc
class __$PollCopyWithImpl<$Res>
    implements _$PollCopyWith<$Res> {
  __$PollCopyWithImpl(this._self, this._then);

  final _Poll _self;
  final $Res Function(_Poll) _then;

/// Create a copy of Poll
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? options = null,Object? totalVotes = null,Object? myVote = freezed,}) {
  return _then(_Poll(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,options: null == options ? _self._options : options // ignore: cast_nullable_to_non_nullable
as List<PollOption>,totalVotes: null == totalVotes ? _self.totalVotes : totalVotes // ignore: cast_nullable_to_non_nullable
as int,myVote: freezed == myVote ? _self.myVote : myVote // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$PublishedMessage {

 String get id; String get groupId; String get text; DisplaySender? get displaySender;/// An image sent with the message (API.md 49), served to group members.
 String? get attachmentId;/// The message this one replies to (API.md 50).
 ReplyQuote? get replyTo;/// Pinned to the top of the chat by the controller.
 bool get pinned;/// Set when the message is a poll.
 Poll? get poll; DateTime get publishedAt;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PublishedMessage&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.groupId, _this.groupId) || other.groupId == _this.groupId)&&(identical(other.text, _this.text) || other.text == _this.text)&&(identical(other.displaySender, _this.displaySender) || other.displaySender == _this.displaySender)&&(identical(other.attachmentId, _this.attachmentId) || other.attachmentId == _this.attachmentId)&&(identical(other.replyTo, _this.replyTo) || other.replyTo == _this.replyTo)&&(identical(other.pinned, _this.pinned) || other.pinned == _this.pinned)&&(identical(other.poll, _this.poll) || other.poll == _this.poll)&&(identical(other.publishedAt, _this.publishedAt) || other.publishedAt == _this.publishedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PublishedMessage;
  return Object.hash(runtimeType,_this.id,_this.groupId,_this.text,_this.displaySender,_this.attachmentId,_this.replyTo,_this.pinned,_this.poll,_this.publishedAt);
}

@override
String toString() {
  final _this = this as PublishedMessage;
  return 'PublishedMessage(id: ${_this.id}, groupId: ${_this.groupId}, text: ${_this.text}, displaySender: ${_this.displaySender}, attachmentId: ${_this.attachmentId}, replyTo: ${_this.replyTo}, pinned: ${_this.pinned}, poll: ${_this.poll}, publishedAt: ${_this.publishedAt})';
}


}

/// @nodoc
abstract mixin class $PublishedMessageCopyWith<$Res>  {
  factory $PublishedMessageCopyWith(PublishedMessage value, $Res Function(PublishedMessage) _then) = _$PublishedMessageCopyWithImpl;
@useResult
$Res call({
 String id, String groupId, String text, DisplaySender? displaySender, String? attachmentId, ReplyQuote? replyTo, bool pinned, Poll? poll, DateTime publishedAt
});


$DisplaySenderCopyWith<$Res>? get displaySender;$ReplyQuoteCopyWith<$Res>? get replyTo;$PollCopyWith<$Res>? get poll;

}
/// @nodoc
class _$PublishedMessageCopyWithImpl<$Res>
    implements $PublishedMessageCopyWith<$Res> {
  _$PublishedMessageCopyWithImpl(this._self, this._then);

  final PublishedMessage _self;
  final $Res Function(PublishedMessage) _then;

/// Create a copy of PublishedMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? groupId = null,Object? text = null,Object? displaySender = freezed,Object? attachmentId = freezed,Object? replyTo = freezed,Object? pinned = null,Object? poll = freezed,Object? publishedAt = null,}) {
  return _then(PublishedMessage(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,displaySender: freezed == displaySender ? _self.displaySender : displaySender // ignore: cast_nullable_to_non_nullable
as DisplaySender?,attachmentId: freezed == attachmentId ? _self.attachmentId : attachmentId // ignore: cast_nullable_to_non_nullable
as String?,replyTo: freezed == replyTo ? _self.replyTo : replyTo // ignore: cast_nullable_to_non_nullable
as ReplyQuote?,pinned: null == pinned ? _self.pinned : pinned // ignore: cast_nullable_to_non_nullable
as bool,poll: freezed == poll ? _self.poll : poll // ignore: cast_nullable_to_non_nullable
as Poll?,publishedAt: null == publishedAt ? _self.publishedAt : publishedAt // ignore: cast_nullable_to_non_nullable
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
}/// Create a copy of PublishedMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReplyQuoteCopyWith<$Res>? get replyTo {
    if (_self.replyTo == null) {
    return null;
  }

  return $ReplyQuoteCopyWith<$Res>(_self.replyTo!, (value) {
    return _then(_self.copyWith(replyTo: value));
  });
}/// Create a copy of PublishedMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PollCopyWith<$Res>? get poll {
    if (_self.poll == null) {
    return null;
  }

  return $PollCopyWith<$Res>(_self.poll!, (value) {
    return _then(_self.copyWith(poll: value));
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String groupId,  String text,  DisplaySender? displaySender,  String? attachmentId,  ReplyQuote? replyTo,  bool pinned,  Poll? poll,  DateTime publishedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PublishedMessage() when $default != null:
return $default(_that.id,_that.groupId,_that.text,_that.displaySender,_that.attachmentId,_that.replyTo,_that.pinned,_that.poll,_that.publishedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String groupId,  String text,  DisplaySender? displaySender,  String? attachmentId,  ReplyQuote? replyTo,  bool pinned,  Poll? poll,  DateTime publishedAt)  $default,) {final _that = this;
switch (_that) {
case _PublishedMessage():
return $default(_that.id,_that.groupId,_that.text,_that.displaySender,_that.attachmentId,_that.replyTo,_that.pinned,_that.poll,_that.publishedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String groupId,  String text,  DisplaySender? displaySender,  String? attachmentId,  ReplyQuote? replyTo,  bool pinned,  Poll? poll,  DateTime publishedAt)?  $default,) {final _that = this;
switch (_that) {
case _PublishedMessage() when $default != null:
return $default(_that.id,_that.groupId,_that.text,_that.displaySender,_that.attachmentId,_that.replyTo,_that.pinned,_that.poll,_that.publishedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PublishedMessage implements PublishedMessage {
  const _PublishedMessage({required this.id, required this.groupId, required this.text, this.displaySender, this.attachmentId, this.replyTo, this.pinned = false, this.poll, required this.publishedAt});
  factory _PublishedMessage.fromJson(Map<String, dynamic> json) => _$PublishedMessageFromJson(json);

@override final  String id;
@override final  String groupId;
@override final  String text;
@override final  DisplaySender? displaySender;
/// An image sent with the message (API.md 49), served to group members.
@override final  String? attachmentId;
/// The message this one replies to (API.md 50).
@override final  ReplyQuote? replyTo;
/// Pinned to the top of the chat by the controller.
@override@JsonKey() final  bool pinned;
/// Set when the message is a poll.
@override final  Poll? poll;
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
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PublishedMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.text, text) || other.text == text)&&(identical(other.displaySender, displaySender) || other.displaySender == displaySender)&&(identical(other.attachmentId, attachmentId) || other.attachmentId == attachmentId)&&(identical(other.replyTo, replyTo) || other.replyTo == replyTo)&&(identical(other.pinned, pinned) || other.pinned == pinned)&&(identical(other.poll, poll) || other.poll == poll)&&(identical(other.publishedAt, publishedAt) || other.publishedAt == publishedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,groupId,text,displaySender,attachmentId,replyTo,pinned,poll,publishedAt);
}

@override
String toString() {
    return 'PublishedMessage(id: $id, groupId: $groupId, text: $text, displaySender: $displaySender, attachmentId: $attachmentId, replyTo: $replyTo, pinned: $pinned, poll: $poll, publishedAt: $publishedAt)';
}


}

/// @nodoc
abstract mixin class _$PublishedMessageCopyWith<$Res> implements $PublishedMessageCopyWith<$Res> {
  factory _$PublishedMessageCopyWith(_PublishedMessage value, $Res Function(_PublishedMessage) _then) = __$PublishedMessageCopyWithImpl;
@override @useResult
$Res call({
 String id, String groupId, String text, DisplaySender? displaySender, String? attachmentId, ReplyQuote? replyTo, bool pinned, Poll? poll, DateTime publishedAt
});


@override $DisplaySenderCopyWith<$Res>? get displaySender;@override $ReplyQuoteCopyWith<$Res>? get replyTo;@override $PollCopyWith<$Res>? get poll;

}
/// @nodoc
class __$PublishedMessageCopyWithImpl<$Res>
    implements _$PublishedMessageCopyWith<$Res> {
  __$PublishedMessageCopyWithImpl(this._self, this._then);

  final _PublishedMessage _self;
  final $Res Function(_PublishedMessage) _then;

/// Create a copy of PublishedMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? groupId = null,Object? text = null,Object? displaySender = freezed,Object? attachmentId = freezed,Object? replyTo = freezed,Object? pinned = null,Object? poll = freezed,Object? publishedAt = null,}) {
  return _then(_PublishedMessage(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,displaySender: freezed == displaySender ? _self.displaySender : displaySender // ignore: cast_nullable_to_non_nullable
as DisplaySender?,attachmentId: freezed == attachmentId ? _self.attachmentId : attachmentId // ignore: cast_nullable_to_non_nullable
as String?,replyTo: freezed == replyTo ? _self.replyTo : replyTo // ignore: cast_nullable_to_non_nullable
as ReplyQuote?,pinned: null == pinned ? _self.pinned : pinned // ignore: cast_nullable_to_non_nullable
as bool,poll: freezed == poll ? _self.poll : poll // ignore: cast_nullable_to_non_nullable
as Poll?,publishedAt: null == publishedAt ? _self.publishedAt : publishedAt // ignore: cast_nullable_to_non_nullable
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
}/// Create a copy of PublishedMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReplyQuoteCopyWith<$Res>? get replyTo {
    if (_self.replyTo == null) {
    return null;
  }

  return $ReplyQuoteCopyWith<$Res>(_self.replyTo!, (value) {
    return _then(_self.copyWith(replyTo: value));
  });
}/// Create a copy of PublishedMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PollCopyWith<$Res>? get poll {
    if (_self.poll == null) {
    return null;
  }

  return $PollCopyWith<$Res>(_self.poll!, (value) {
    return _then(_self.copyWith(poll: value));
  });
}
}

// dart format on
