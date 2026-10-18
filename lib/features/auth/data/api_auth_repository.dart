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
  Future<void> logout() {
    return guardApi(() async {
      await _dio.post(Endpoints.logout);
    });
  }
}
