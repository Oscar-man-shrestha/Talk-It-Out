import 'package:dio/dio.dart';
import 'package:talk_it_out/core/api/api_guard.dart';
import 'package:talk_it_out/core/api/endpoints.dart';
import 'package:talk_it_out/core/models/user.dart';
import 'package:talk_it_out/features/auth/data/auth_repository.dart';
import 'package:talk_it_out/features/auth/data/auth_session.dart';

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._dio);

  final Dio _dio;

  @override
  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
  }) {
    return guardApi(() async {
      final response = await _dio.post(
        Endpoints.register,
        data: {'name': name, 'email': email, 'password': password},
      );
      return AuthSession.fromJson(asJsonMap(response.data));
    });
  }

  @override
  Future<AuthSession> login({required String email, required String password}) {
    return guardApi(() async {
      final response = await _dio.post(
        Endpoints.login,
        data: {'email': email, 'password': password},
      );
      return AuthSession.fromJson(asJsonMap(response.data));
    });
  }

  @override
  Future<User> me() {
    return guardApi(() async {
      final response = await _dio.get(Endpoints.me);
      return User.fromJson(asJsonMap(response.data));
    });
  }

  @override
  Future<String?> issueRefreshToken() async {
    try {
      final response = await _dio.post(Endpoints.refreshTokens);
      final token = asJsonMap(response.data)['refresh_token'];
      return token is String && token.isNotEmpty ? token : null;
    } catch (_) {
      // Optional: without it the user simply signs in again when the access
      // token expires, exactly as before.
      return null;
    }
  }

  @override
  Future<void> deleteAccount({required String password}) {
    return guardApi(() async {
      await _dio.delete(Endpoints.myAccount, data: {'password': password});
    });
  }

  @override
  Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return guardApi(() async {
      final response = await _dio.post(
        Endpoints.changePassword,
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
      final token = asJsonMap(response.data)['token'];
      if (token is! String || token.isEmpty) {
        throw const FormatException('missing token');
      }
      return token;
    });
  }

  @override
  Future<void> logoutAll() {
    return guardApi(() async {
      await _dio.post(Endpoints.logoutAll);
    });
  }

  @override
  Future<void> requestPasswordReset({required String email}) {
    return guardApi(() async {
      await _dio.post(Endpoints.passwordReset, data: {'email': email});
    });
  }

  @override
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) {
    return guardApi(() async {
      await _dio.post(
        Endpoints.passwordResetConfirm,
        data: {'email': email, 'code': code, 'new_password': newPassword},
      );
    });
  }

  @override
  Future<void> logout() {
    return guardApi(() async {
      try {
        await _dio.delete(Endpoints.refreshTokens);
      } catch (_) {
        // Revoking is best-effort; local sign-out still happens.
      }
      await _dio.post(Endpoints.logout);
    });
  }
}
