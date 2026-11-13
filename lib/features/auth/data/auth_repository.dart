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

  /// Asks for a long-lived refresh token for the signed-in user. Returns
  /// null when the backend does not offer one (the mock never does).
  Future<String?> issueRefreshToken();

  Future<void> logout();
}
