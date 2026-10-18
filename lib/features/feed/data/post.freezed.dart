// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'post.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Post {

 String get id; Author get author; String get content; bool get nsfwFlag;@JsonKey(fromJson: flagsFromJson) Map<String, dynamic> get otherFlags; int get reactionCount; String? get myReaction; int get commentCount; DateTime get createdAt;
/// Create a copy of Post
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PostCopyWith<Post> get copyWith => _$PostCopyWithImpl<Post>(this as Post, _$identity);

  /// Serializes this Post to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Post;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Post&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.author, _this.author) || other.author == _this.author)&&(identical(other.content, _this.content) || other.content == _this.content)&&(identical(other.nsfwFlag, _this.nsfwFlag) || other.nsfwFlag == _this.nsfwFlag)&&const DeepCollectionEquality().equals(other.otherFlags, _this.otherFlags)&&(identical(other.reactionCount, _this.reactionCount) || other.reactionCount == _this.reactionCount)&&(identical(other.myReaction, _this.myReaction) || other.myReaction == _this.myReaction)&&(identical(other.commentCount, _this.commentCount) || other.commentCount == _this.commentCount)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Post;
  return Object.hash(runtimeType,_this.id,_this.author,_this.content,_this.nsfwFlag,const DeepCollectionEquality().hash(_this.otherFlags),_this.reactionCount,_this.myReaction,_this.commentCount,_this.createdAt);
}

@override
String toString() {
  final _this = this as Post;
  return 'Post(id: ${_this.id}, author: ${_this.author}, content: ${_this.content}, nsfwFlag: ${_this.nsfwFlag}, otherFlags: ${_this.otherFlags}, reactionCount: ${_this.reactionCount}, myReaction: ${_this.myReaction}, commentCount: ${_this.commentCount}, createdAt: ${_this.createdAt})';
}


}

/// @nodoc
abstract mixin class $PostCopyWith<$Res>  {
  factory $PostCopyWith(Post value, $Res Function(Post) _then) = _$PostCopyWithImpl;
@useResult
$Res call({
 String id, Author author, String content, bool nsfwFlag,@JsonKey(fromJson: flagsFromJson) Map<String, dynamic> otherFlags, int reactionCount, String? myReaction, int commentCount, DateTime createdAt
});


$AuthorCopyWith<$Res> get author;

}
/// @nodoc
class _$PostCopyWithImpl<$Res>
    implements $PostCopyWith<$Res> {
  _$PostCopyWithImpl(this._self, this._then);

  final Post _self;
  final $Res Function(Post) _then;

/// Create a copy of Post
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? author = null,Object? content = null,Object? nsfwFlag = null,Object? otherFlags = null,Object? reactionCount = null,Object? myReaction = freezed,Object? commentCount = null,Object? createdAt = null,}) {
  return _then(Post(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as Author,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,nsfwFlag: null == nsfwFlag ? _self.nsfwFlag : nsfwFlag // ignore: cast_nullable_to_non_nullable
as bool,otherFlags: null == otherFlags ? _self.otherFlags : otherFlags // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,reactionCount: null == reactionCount ? _self.reactionCount : reactionCount // ignore: cast_nullable_to_non_nullable
as int,myReaction: freezed == myReaction ? _self.myReaction : myReaction // ignore: cast_nullable_to_non_nullable
as String?,commentCount: null == commentCount ? _self.commentCount : commentCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}
/// Create a copy of Post
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AuthorCopyWith<$Res> get author {
  
  return $AuthorCopyWith<$Res>(_self.author, (value) {
    return _then(_self.copyWith(author: value));
  });
}
}


/// Adds pattern-matching-related methods to [Post].
extension PostPatterns on Post {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Post value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Post() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Post value)  $default,){
final _that = this;
switch (_that) {
case _Post():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Post value)?  $default,){
final _that = this;
switch (_that) {
case _Post() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  Author author,  String content,  bool nsfwFlag, @JsonKey(fromJson: flagsFromJson)  Map<String, dynamic> otherFlags,  int reactionCount,  String? myReaction,  int commentCount,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Post() when $default != null:
return $default(_that.id,_that.author,_that.content,_that.nsfwFlag,_that.otherFlags,_that.reactionCount,_that.myReaction,_that.commentCount,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  Author author,  String content,  bool nsfwFlag, @JsonKey(fromJson: flagsFromJson)  Map<String, dynamic> otherFlags,  int reactionCount,  String? myReaction,  int commentCount,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _Post():
return $default(_that.id,_that.author,_that.content,_that.nsfwFlag,_that.otherFlags,_that.reactionCount,_that.myReaction,_that.commentCount,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  Author author,  String content,  bool nsfwFlag, @JsonKey(fromJson: flagsFromJson)  Map<String, dynamic> otherFlags,  int reactionCount,  String? myReaction,  int commentCount,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _Post() when $default != null:
return $default(_that.id,_that.author,_that.content,_that.nsfwFlag,_that.otherFlags,_that.reactionCount,_that.myReaction,_that.commentCount,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Post implements Post {
  const _Post({required this.id, required this.author, required this.content, required this.nsfwFlag, @JsonKey(fromJson: flagsFromJson)  Map<String, dynamic> otherFlags = const <String, dynamic>{}, required this.reactionCount, this.myReaction, required this.commentCount, required this.createdAt}): _otherFlags = otherFlags;
  factory _Post.fromJson(Map<String, dynamic> json) => _$PostFromJson(json);

@override final  String id;
@override final  Author author;
@override final  String content;
@override final  bool nsfwFlag;
 final  Map<String, dynamic> _otherFlags;
@override@JsonKey(fromJson: flagsFromJson) Map<String, dynamic> get otherFlags {
  if (_otherFlags is EqualUnmodifiableMapView) return _otherFlags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_otherFlags);
}

@override final  int reactionCount;
@override final  String? myReaction;
@override final  int commentCount;
@override final  DateTime createdAt;

/// Create a copy of Post
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PostCopyWith<_Post> get copyWith => __$PostCopyWithImpl<_Post>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PostToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Post&&(identical(other.id, id) || other.id == id)&&(identical(other.author, author) || other.author == author)&&(identical(other.content, content) || other.content == content)&&(identical(other.nsfwFlag, nsfwFlag) || other.nsfwFlag == nsfwFlag)&&const DeepCollectionEquality().equals(other.otherFlags, _otherFlags)&&(identical(other.reactionCount, reactionCount) || other.reactionCount == reactionCount)&&(identical(other.myReaction, myReaction) || other.myReaction == myReaction)&&(identical(other.commentCount, commentCount) || other.commentCount == commentCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,author,content,nsfwFlag,const DeepCollectionEquality().hash(_otherFlags),reactionCount,myReaction,commentCount,createdAt);
}

@override
String toString() {
    return 'Post(id: $id, author: $author, content: $content, nsfwFlag: $nsfwFlag, otherFlags: $otherFlags, reactionCount: $reactionCount, myReaction: $myReaction, commentCount: $commentCount, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$PostCopyWith<$Res> implements $PostCopyWith<$Res> {
  factory _$PostCopyWith(_Post value, $Res Function(_Post) _then) = __$PostCopyWithImpl;
@override @useResult
$Res call({
 String id, Author author, String content, bool nsfwFlag,@JsonKey(fromJson: flagsFromJson) Map<String, dynamic> otherFlags, int reactionCount, String? myReaction, int commentCount, DateTime createdAt
});


@override $AuthorCopyWith<$Res> get author;

}
/// @nodoc
class __$PostCopyWithImpl<$Res>
    implements _$PostCopyWith<$Res> {
  __$PostCopyWithImpl(this._self, this._then);

  final _Post _self;
  final $Res Function(_Post) _then;

/// Create a copy of Post
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? author = null,Object? content = null,Object? nsfwFlag = null,Object? otherFlags = null,Object? reactionCount = null,Object? myReaction = freezed,Object? commentCount = null,Object? createdAt = null,}) {
  return _then(_Post(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as Author,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,nsfwFlag: null == nsfwFlag ? _self.nsfwFlag : nsfwFlag // ignore: cast_nullable_to_non_nullable
as bool,otherFlags: null == otherFlags ? _self._otherFlags : otherFlags // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,reactionCount: null == reactionCount ? _self.reactionCount : reactionCount // ignore: cast_nullable_to_non_nullable
as int,myReaction: freezed == myReaction ? _self.myReaction : myReaction // ignore: cast_nullable_to_non_nullable
as String?,commentCount: null == commentCount ? _self.commentCount : commentCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

/// Create a copy of Post
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
