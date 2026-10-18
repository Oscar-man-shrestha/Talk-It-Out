import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:talk_it_out/core/models/user.dart';

part 'auth_session.freezed.dart';
part 'auth_session.g.dart';

@freezed
abstract class AuthSession with _$AuthSession {
  const factory AuthSession({required String token, required User user}) =
      _AuthSession;

  factory AuthSession.fromJson(Map<String, dynamic> json) =>
      _$AuthSessionFromJson(json);
}
