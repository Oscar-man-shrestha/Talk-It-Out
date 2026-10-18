// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'comment.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Comment {

 String get id; String get postId; Author get author; String get content; bool get nsfwFlag;@JsonKey(fromJson: flagsFromJson) Map<String, dynamic> get otherFlags; DateTime get createdAt;
/// Create a copy of Comment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CommentCopyWith<Comment> get copyWith => _$CommentCopyWithImpl<Comment>(this as Comment, _$identity);

  /// Serializes this Comment to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Comment;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Comment&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.postId, _this.postId) || other.postId == _this.postId)&&(identical(other.author, _this.author) || other.author == _this.author)&&(identical(other.content, _this.content) || other.content == _this.content)&&(identical(other.nsfwFlag, _this.nsfwFlag) || other.nsfwFlag == _this.nsfwFlag)&&const DeepCollectionEquality().equals(other.otherFlags, _this.otherFlags)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Comment;
  return Object.hash(runtimeType,_this.id,_this.postId,_this.author,_this.content,_this.nsfwFlag,const DeepCollectionEquality().hash(_this.otherFlags),_this.createdAt);
}

@override
String toString() {
  final _this = this as Comment;
  return 'Comment(id: ${_this.id}, postId: ${_this.postId}, author: ${_this.author}, content: ${_this.content}, nsfwFlag: ${_this.nsfwFlag}, otherFlags: ${_this.otherFlags}, createdAt: ${_this.createdAt})';
}


}

/// @nodoc
abstract mixin class $CommentCopyWith<$Res>  {
  factory $CommentCopyWith(Comment value, $Res Function(Comment) _then) = _$CommentCopyWithImpl;
@useResult
$Res call({
 String id, String postId, Author author, String content, bool nsfwFlag,@JsonKey(fromJson: flagsFromJson) Map<String, dynamic> otherFlags, DateTime createdAt
});


$AuthorCopyWith<$Res> get author;

}
/// @nodoc
class _$CommentCopyWithImpl<$Res>
    implements $CommentCopyWith<$Res> {
  _$CommentCopyWithImpl(this._self, this._then);

  final Comment _self;
  final $Res Function(Comment) _then;

/// Create a copy of Comment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? postId = null,Object? author = null,Object? content = null,Object? nsfwFlag = null,Object? otherFlags = null,Object? createdAt = null,}) {
  return _then(Comment(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,postId: null == postId ? _self.postId : postId // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as Author,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,nsfwFlag: null == nsfwFlag ? _self.nsfwFlag : nsfwFlag // ignore: cast_nullable_to_non_nullable
as bool,otherFlags: null == otherFlags ? _self.otherFlags : otherFlags // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}
/// Create a copy of Comment
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AuthorCopyWith<$Res> get author {
  
  return $AuthorCopyWith<$Res>(_self.author, (value) {
    return _then(_self.copyWith(author: value));
  });
}
}


/// Adds pattern-matching-related methods to [Comment].
extension CommentPatterns on Comment {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Comment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Comment() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Comment value)  $default,){
final _that = this;
switch (_that) {
case _Comment():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Comment value)?  $default,){
final _that = this;
switch (_that) {
case _Comment() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String postId,  Author author,  String content,  bool nsfwFlag, @JsonKey(fromJson: flagsFromJson)  Map<String, dynamic> otherFlags,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Comment() when $default != null:
return $default(_that.id,_that.postId,_that.author,_that.content,_that.nsfwFlag,_that.otherFlags,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String postId,  Author author,  String content,  bool nsfwFlag, @JsonKey(fromJson: flagsFromJson)  Map<String, dynamic> otherFlags,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _Comment():
return $default(_that.id,_that.postId,_that.author,_that.content,_that.nsfwFlag,_that.otherFlags,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String postId,  Author author,  String content,  bool nsfwFlag, @JsonKey(fromJson: flagsFromJson)  Map<String, dynamic> otherFlags,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _Comment() when $default != null:
return $default(_that.id,_that.postId,_that.author,_that.content,_that.nsfwFlag,_that.otherFlags,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Comment implements Comment {
  const _Comment({required this.id, required this.postId, required this.author, required this.content, required this.nsfwFlag, @JsonKey(fromJson: flagsFromJson)  Map<String, dynamic> otherFlags = const <String, dynamic>{}, required this.createdAt}): _otherFlags = otherFlags;
  factory _Comment.fromJson(Map<String, dynamic> json) => _$CommentFromJson(json);

@override final  String id;
@override final  String postId;
@override final  Author author;
@override final  String content;
@override final  bool nsfwFlag;
 final  Map<String, dynamic> _otherFlags;
@override@JsonKey(fromJson: flagsFromJson) Map<String, dynamic> get otherFlags {
  if (_otherFlags is EqualUnmodifiableMapView) return _otherFlags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_otherFlags);
}

@override final  DateTime createdAt;

/// Create a copy of Comment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CommentCopyWith<_Comment> get copyWith => __$CommentCopyWithImpl<_Comment>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CommentToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Comment&&(identical(other.id, id) || other.id == id)&&(identical(other.postId, postId) || other.postId == postId)&&(identical(other.author, author) || other.author == author)&&(identical(other.content, content) || other.content == content)&&(identical(other.nsfwFlag, nsfwFlag) || other.nsfwFlag == nsfwFlag)&&const DeepCollectionEquality().equals(other.otherFlags, _otherFlags)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,postId,author,content,nsfwFlag,const DeepCollectionEquality().hash(_otherFlags),createdAt);
}

@override
String toString() {
    return 'Comment(id: $id, postId: $postId, author: $author, content: $content, nsfwFlag: $nsfwFlag, otherFlags: $otherFlags, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$CommentCopyWith<$Res> implements $CommentCopyWith<$Res> {
  factory _$CommentCopyWith(_Comment value, $Res Function(_Comment) _then) = __$CommentCopyWithImpl;
@override @useResult
$Res call({
 String id, String postId, Author author, String content, bool nsfwFlag,@JsonKey(fromJson: flagsFromJson) Map<String, dynamic> otherFlags, DateTime createdAt
});


@override $AuthorCopyWith<$Res> get author;

}
/// @nodoc
class __$CommentCopyWithImpl<$Res>
    implements _$CommentCopyWith<$Res> {
  __$CommentCopyWithImpl(this._self, this._then);

  final _Comment _self;
  final $Res Function(_Comment) _then;

/// Create a copy of Comment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? postId = null,Object? author = null,Object? content = null,Object? nsfwFlag = null,Object? otherFlags = null,Object? createdAt = null,}) {
  return _then(_Comment(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,postId: null == postId ? _self.postId : postId // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as Author,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,nsfwFlag: null == nsfwFlag ? _self.nsfwFlag : nsfwFlag // ignore: cast_nullable_to_non_nullable
as bool,otherFlags: null == otherFlags ? _self._otherFlags : otherFlags // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

/// Create a copy of Comment
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AuthorCopyWith<$Res> get author {
  
  return $AuthorCopyWith<$Res>(_self.author, (value) {
    return _then(_self.copyWith(author: value));
  });
}
}

// dart format on
