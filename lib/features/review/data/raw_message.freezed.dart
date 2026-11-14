// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'raw_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RawMessage {

 String get id; String get groupId; String get senderId; String get senderName; String get originalText; String? get rewrittenText; bool get isAnonymous;@JsonKey(fromJson: nullableDoubleFromJson) double? get intentPreservationScore;@JsonKey(fromJson: nullableDoubleFromJson) double? get relevanceScore;@JsonKey(unknownEnumValue: RelevanceLabel.borderline) RelevanceLabel? get relevanceLabel;@JsonKey(unknownEnumValue: PipelineStatus.processing) PipelineStatus get pipelineStatus;@JsonKey(unknownEnumValue: MessageStatus.pending) MessageStatus get status; DateTime get createdAt;/// When the controller accepted or rejected it; null while pending.
 DateTime? get decidedAt;/// An image sent with the message, shown to the controller in review.
 String? get attachmentId;
/// Create a copy of RawMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RawMessageCopyWith<RawMessage> get copyWith => _$RawMessageCopyWithImpl<RawMessage>(this as RawMessage, _$identity);

  /// Serializes this RawMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RawMessage;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RawMessage&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.groupId, _this.groupId) || other.groupId == _this.groupId)&&(identical(other.senderId, _this.senderId) || other.senderId == _this.senderId)&&(identical(other.senderName, _this.senderName) || other.senderName == _this.senderName)&&(identical(other.originalText, _this.originalText) || other.originalText == _this.originalText)&&(identical(other.rewrittenText, _this.rewrittenText) || other.rewrittenText == _this.rewrittenText)&&(identical(other.isAnonymous, _this.isAnonymous) || other.isAnonymous == _this.isAnonymous)&&(identical(other.intentPreservationScore, _this.intentPreservationScore) || other.intentPreservationScore == _this.intentPreservationScore)&&(identical(other.relevanceScore, _this.relevanceScore) || other.relevanceScore == _this.relevanceScore)&&(identical(other.relevanceLabel, _this.relevanceLabel) || other.relevanceLabel == _this.relevanceLabel)&&(identical(other.pipelineStatus, _this.pipelineStatus) || other.pipelineStatus == _this.pipelineStatus)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.decidedAt, _this.decidedAt) || other.decidedAt == _this.decidedAt)&&(identical(other.attachmentId, _this.attachmentId) || other.attachmentId == _this.attachmentId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RawMessage;
  return Object.hash(runtimeType,_this.id,_this.groupId,_this.senderId,_this.senderName,_this.originalText,_this.rewrittenText,_this.isAnonymous,_this.intentPreservationScore,_this.relevanceScore,_this.relevanceLabel,_this.pipelineStatus,_this.status,_this.createdAt,_this.decidedAt,_this.attachmentId);
}

@override
String toString() {
  final _this = this as RawMessage;
  return 'RawMessage(id: ${_this.id}, groupId: ${_this.groupId}, senderId: ${_this.senderId}, senderName: ${_this.senderName}, originalText: ${_this.originalText}, rewrittenText: ${_this.rewrittenText}, isAnonymous: ${_this.isAnonymous}, intentPreservationScore: ${_this.intentPreservationScore}, relevanceScore: ${_this.relevanceScore}, relevanceLabel: ${_this.relevanceLabel}, pipelineStatus: ${_this.pipelineStatus}, status: ${_this.status}, createdAt: ${_this.createdAt}, decidedAt: ${_this.decidedAt}, attachmentId: ${_this.attachmentId})';
}


}

/// @nodoc
abstract mixin class $RawMessageCopyWith<$Res>  {
  factory $RawMessageCopyWith(RawMessage value, $Res Function(RawMessage) _then) = _$RawMessageCopyWithImpl;
@useResult
$Res call({
 String id, String groupId, String senderId, String senderName, String originalText, String? rewrittenText, bool isAnonymous,@JsonKey(fromJson: nullableDoubleFromJson) double? intentPreservationScore,@JsonKey(fromJson: nullableDoubleFromJson) double? relevanceScore,@JsonKey(unknownEnumValue: RelevanceLabel.borderline) RelevanceLabel? relevanceLabel,@JsonKey(unknownEnumValue: PipelineStatus.processing) PipelineStatus pipelineStatus,@JsonKey(unknownEnumValue: MessageStatus.pending) MessageStatus status, DateTime createdAt, DateTime? decidedAt, String? attachmentId
});




}
/// @nodoc
class _$RawMessageCopyWithImpl<$Res>
    implements $RawMessageCopyWith<$Res> {
  _$RawMessageCopyWithImpl(this._self, this._then);

  final RawMessage _self;
  final $Res Function(RawMessage) _then;

/// Create a copy of RawMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? groupId = null,Object? senderId = null,Object? senderName = null,Object? originalText = null,Object? rewrittenText = freezed,Object? isAnonymous = null,Object? intentPreservationScore = freezed,Object? relevanceScore = freezed,Object? relevanceLabel = freezed,Object? pipelineStatus = null,Object? status = null,Object? createdAt = null,Object? decidedAt = freezed,Object? attachmentId = freezed,}) {
  return _then(RawMessage(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String,senderId: null == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String,senderName: null == senderName ? _self.senderName : senderName // ignore: cast_nullable_to_non_nullable
as String,originalText: null == originalText ? _self.originalText : originalText // ignore: cast_nullable_to_non_nullable
as String,rewrittenText: freezed == rewrittenText ? _self.rewrittenText : rewrittenText // ignore: cast_nullable_to_non_nullable
as String?,isAnonymous: null == isAnonymous ? _self.isAnonymous : isAnonymous // ignore: cast_nullable_to_non_nullable
as bool,intentPreservationScore: freezed == intentPreservationScore ? _self.intentPreservationScore : intentPreservationScore // ignore: cast_nullable_to_non_nullable
as double?,relevanceScore: freezed == relevanceScore ? _self.relevanceScore : relevanceScore // ignore: cast_nullable_to_non_nullable
as double?,relevanceLabel: freezed == relevanceLabel ? _self.relevanceLabel : relevanceLabel // ignore: cast_nullable_to_non_nullable
as RelevanceLabel?,pipelineStatus: null == pipelineStatus ? _self.pipelineStatus : pipelineStatus // ignore: cast_nullable_to_non_nullable
as PipelineStatus,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MessageStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,decidedAt: freezed == decidedAt ? _self.decidedAt : decidedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,attachmentId: freezed == attachmentId ? _self.attachmentId : attachmentId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [RawMessage].
extension RawMessagePatterns on RawMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RawMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RawMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RawMessage value)  $default,){
final _that = this;
switch (_that) {
case _RawMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RawMessage value)?  $default,){
final _that = this;
switch (_that) {
case _RawMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String groupId,  String senderId,  String senderName,  String originalText,  String? rewrittenText,  bool isAnonymous, @JsonKey(fromJson: nullableDoubleFromJson)  double? intentPreservationScore, @JsonKey(fromJson: nullableDoubleFromJson)  double? relevanceScore, @JsonKey(unknownEnumValue: RelevanceLabel.borderline)  RelevanceLabel? relevanceLabel, @JsonKey(unknownEnumValue: PipelineStatus.processing)  PipelineStatus pipelineStatus, @JsonKey(unknownEnumValue: MessageStatus.pending)  MessageStatus status,  DateTime createdAt,  DateTime? decidedAt,  String? attachmentId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RawMessage() when $default != null:
return $default(_that.id,_that.groupId,_that.senderId,_that.senderName,_that.originalText,_that.rewrittenText,_that.isAnonymous,_that.intentPreservationScore,_that.relevanceScore,_that.relevanceLabel,_that.pipelineStatus,_that.status,_that.createdAt,_that.decidedAt,_that.attachmentId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String groupId,  String senderId,  String senderName,  String originalText,  String? rewrittenText,  bool isAnonymous, @JsonKey(fromJson: nullableDoubleFromJson)  double? intentPreservationScore, @JsonKey(fromJson: nullableDoubleFromJson)  double? relevanceScore, @JsonKey(unknownEnumValue: RelevanceLabel.borderline)  RelevanceLabel? relevanceLabel, @JsonKey(unknownEnumValue: PipelineStatus.processing)  PipelineStatus pipelineStatus, @JsonKey(unknownEnumValue: MessageStatus.pending)  MessageStatus status,  DateTime createdAt,  DateTime? decidedAt,  String? attachmentId)  $default,) {final _that = this;
switch (_that) {
case _RawMessage():
return $default(_that.id,_that.groupId,_that.senderId,_that.senderName,_that.originalText,_that.rewrittenText,_that.isAnonymous,_that.intentPreservationScore,_that.relevanceScore,_that.relevanceLabel,_that.pipelineStatus,_that.status,_that.createdAt,_that.decidedAt,_that.attachmentId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String groupId,  String senderId,  String senderName,  String originalText,  String? rewrittenText,  bool isAnonymous, @JsonKey(fromJson: nullableDoubleFromJson)  double? intentPreservationScore, @JsonKey(fromJson: nullableDoubleFromJson)  double? relevanceScore, @JsonKey(unknownEnumValue: RelevanceLabel.borderline)  RelevanceLabel? relevanceLabel, @JsonKey(unknownEnumValue: PipelineStatus.processing)  PipelineStatus pipelineStatus, @JsonKey(unknownEnumValue: MessageStatus.pending)  MessageStatus status,  DateTime createdAt,  DateTime? decidedAt,  String? attachmentId)?  $default,) {final _that = this;
switch (_that) {
case _RawMessage() when $default != null:
return $default(_that.id,_that.groupId,_that.senderId,_that.senderName,_that.originalText,_that.rewrittenText,_that.isAnonymous,_that.intentPreservationScore,_that.relevanceScore,_that.relevanceLabel,_that.pipelineStatus,_that.status,_that.createdAt,_that.decidedAt,_that.attachmentId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RawMessage extends RawMessage {
  const _RawMessage({required this.id, required this.groupId, required this.senderId, required this.senderName, required this.originalText, this.rewrittenText, required this.isAnonymous, @JsonKey(fromJson: nullableDoubleFromJson) this.intentPreservationScore, @JsonKey(fromJson: nullableDoubleFromJson) this.relevanceScore, @JsonKey(unknownEnumValue: RelevanceLabel.borderline) this.relevanceLabel, @JsonKey(unknownEnumValue: PipelineStatus.processing) required this.pipelineStatus, @JsonKey(unknownEnumValue: MessageStatus.pending) required this.status, required this.createdAt, this.decidedAt, this.attachmentId}): super._();
  factory _RawMessage.fromJson(Map<String, dynamic> json) => _$RawMessageFromJson(json);

@override final  String id;
@override final  String groupId;
@override final  String senderId;
@override final  String senderName;
@override final  String originalText;
@override final  String? rewrittenText;
@override final  bool isAnonymous;
@override@JsonKey(fromJson: nullableDoubleFromJson) final  double? intentPreservationScore;
@override@JsonKey(fromJson: nullableDoubleFromJson) final  double? relevanceScore;
@override@JsonKey(unknownEnumValue: RelevanceLabel.borderline) final  RelevanceLabel? relevanceLabel;
@override@JsonKey(unknownEnumValue: PipelineStatus.processing) final  PipelineStatus pipelineStatus;
@override@JsonKey(unknownEnumValue: MessageStatus.pending) final  MessageStatus status;
@override final  DateTime createdAt;
/// When the controller accepted or rejected it; null while pending.
@override final  DateTime? decidedAt;
/// An image sent with the message, shown to the controller in review.
@override final  String? attachmentId;

/// Create a copy of RawMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RawMessageCopyWith<_RawMessage> get copyWith => __$RawMessageCopyWithImpl<_RawMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RawMessageToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RawMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.senderName, senderName) || other.senderName == senderName)&&(identical(other.originalText, originalText) || other.originalText == originalText)&&(identical(other.rewrittenText, rewrittenText) || other.rewrittenText == rewrittenText)&&(identical(other.isAnonymous, isAnonymous) || other.isAnonymous == isAnonymous)&&(identical(other.intentPreservationScore, intentPreservationScore) || other.intentPreservationScore == intentPreservationScore)&&(identical(other.relevanceScore, relevanceScore) || other.relevanceScore == relevanceScore)&&(identical(other.relevanceLabel, relevanceLabel) || other.relevanceLabel == relevanceLabel)&&(identical(other.pipelineStatus, pipelineStatus) || other.pipelineStatus == pipelineStatus)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.decidedAt, decidedAt) || other.decidedAt == decidedAt)&&(identical(other.attachmentId, attachmentId) || other.attachmentId == attachmentId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,groupId,senderId,senderName,originalText,rewrittenText,isAnonymous,intentPreservationScore,relevanceScore,relevanceLabel,pipelineStatus,status,createdAt,decidedAt,attachmentId);
}

@override
String toString() {
    return 'RawMessage(id: $id, groupId: $groupId, senderId: $senderId, senderName: $senderName, originalText: $originalText, rewrittenText: $rewrittenText, isAnonymous: $isAnonymous, intentPreservationScore: $intentPreservationScore, relevanceScore: $relevanceScore, relevanceLabel: $relevanceLabel, pipelineStatus: $pipelineStatus, status: $status, createdAt: $createdAt, decidedAt: $decidedAt, attachmentId: $attachmentId)';
}


}

/// @nodoc
abstract mixin class _$RawMessageCopyWith<$Res> implements $RawMessageCopyWith<$Res> {
  factory _$RawMessageCopyWith(_RawMessage value, $Res Function(_RawMessage) _then) = __$RawMessageCopyWithImpl;
@override @useResult
$Res call({
 String id, String groupId, String senderId, String senderName, String originalText, String? rewrittenText, bool isAnonymous,@JsonKey(fromJson: nullableDoubleFromJson) double? intentPreservationScore,@JsonKey(fromJson: nullableDoubleFromJson) double? relevanceScore,@JsonKey(unknownEnumValue: RelevanceLabel.borderline) RelevanceLabel? relevanceLabel,@JsonKey(unknownEnumValue: PipelineStatus.processing) PipelineStatus pipelineStatus,@JsonKey(unknownEnumValue: MessageStatus.pending) MessageStatus status, DateTime createdAt, DateTime? decidedAt, String? attachmentId
});




}
/// @nodoc
class __$RawMessageCopyWithImpl<$Res>
    implements _$RawMessageCopyWith<$Res> {
  __$RawMessageCopyWithImpl(this._self, this._then);

  final _RawMessage _self;
  final $Res Function(_RawMessage) _then;

/// Create a copy of RawMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? groupId = null,Object? senderId = null,Object? senderName = null,Object? originalText = null,Object? rewrittenText = freezed,Object? isAnonymous = null,Object? intentPreservationScore = freezed,Object? relevanceScore = freezed,Object? relevanceLabel = freezed,Object? pipelineStatus = null,Object? status = null,Object? createdAt = null,Object? decidedAt = freezed,Object? attachmentId = freezed,}) {
  return _then(_RawMessage(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String,senderId: null == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String,senderName: null == senderName ? _self.senderName : senderName // ignore: cast_nullable_to_non_nullable
as String,originalText: null == originalText ? _self.originalText : originalText // ignore: cast_nullable_to_non_nullable
as String,rewrittenText: freezed == rewrittenText ? _self.rewrittenText : rewrittenText // ignore: cast_nullable_to_non_nullable
as String?,isAnonymous: null == isAnonymous ? _self.isAnonymous : isAnonymous // ignore: cast_nullable_to_non_nullable
as bool,intentPreservationScore: freezed == intentPreservationScore ? _self.intentPreservationScore : intentPreservationScore // ignore: cast_nullable_to_non_nullable
as double?,relevanceScore: freezed == relevanceScore ? _self.relevanceScore : relevanceScore // ignore: cast_nullable_to_non_nullable
as double?,relevanceLabel: freezed == relevanceLabel ? _self.relevanceLabel : relevanceLabel // ignore: cast_nullable_to_non_nullable
as RelevanceLabel?,pipelineStatus: null == pipelineStatus ? _self.pipelineStatus : pipelineStatus // ignore: cast_nullable_to_non_nullable
as PipelineStatus,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MessageStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,decidedAt: freezed == decidedAt ? _self.decidedAt : decidedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,attachmentId: freezed == attachmentId ? _self.attachmentId : attachmentId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
