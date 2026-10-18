import 'package:talk_it_out/core/models/user.dart';
import 'package:talk_it_out/features/auth/data/auth_session.dart';

abstract class AuthRepository {
  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
  });

  Future<AuthSession> login({required String email, required String password});

  Future<User> me();

  Future<void> logout();
}
