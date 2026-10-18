import 'package:freezed_annotation/freezed_annotation.dart';

part 'unread_count.freezed.dart';
part 'unread_count.g.dart';

@freezed
abstract class UnreadCount with _$UnreadCount {
  const factory UnreadCount({required int count}) = _UnreadCount;

  factory UnreadCount.fromJson(Map<String, dynamic> json) =>
      _$UnreadCountFromJson(json);
}
