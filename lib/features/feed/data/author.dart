import 'package:freezed_annotation/freezed_annotation.dart';

part 'author.freezed.dart';
part 'author.g.dart';

@freezed
abstract class Author with _$Author {
  const factory Author({
    required String id,
    required String name,

    /// Premium member: a crown beside the name in the public feed only.
    @Default(false) bool premium,
  }) = _Author;

  factory Author.fromJson(Map<String, dynamic> json) => _$AuthorFromJson(json);
}
