import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:talk_it_out/app/providers.dart';
import 'package:talk_it_out/core/api/endpoints.dart';
import 'package:talk_it_out/core/storage/token_store.dart';
import 'package:talk_it_out/features/auth/auth_events.dart';

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => SecureTokenStore(const FlutterSecureStorage()),
);

/// Marks a request that was already retried after a token refresh.
const _retriedKey = 'auth_retried';

final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final tokens = ref.watch(tokenStoreProvider);
  final events = ref.watch(authEventsProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      headers: const {'Content-Type': 'application/json'},
    ),
  );
  // Shares this client: the refresh call is excluded from the retry logic
  // below, so it can never loop.
  final refresher = TokenRefresher(dio, tokens);
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await tokens.read();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final request = error.requestOptions;
        final unauthorized = error.response?.statusCode == 401;
        if (!unauthorized) return handler.next(error);

        // Try once to swap the refresh token for a new access token, then
        // replay the request. Sign-in calls never trigger a refresh.
        final isAuthCall =
            request.path == Endpoints.login ||
            request.path == Endpoints.register ||
            request.path == Endpoints.refresh;
        if (!isAuthCall && request.extra[_retriedKey] != true) {
          final fresh = await refresher.refresh();
          if (fresh != null) {
            request.extra[_retriedKey] = true;
            request.headers['Authorization'] = 'Bearer $fresh';
            try {
              return handler.resolve(await dio.fetch<dynamic>(request));
            } on DioException catch (retryError) {
              return handler.next(retryError);
            }
          }
        }
        await tokens.clear();
        events.onUnauthorized?.call();
        handler.next(error);
      },
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});

/// Exchanges the stored refresh token for new tokens (`API.md` 35).
///
/// The backend rotates the refresh token on every use and revokes the whole
/// family if an old one is replayed, so concurrent 401s must share a single
/// exchange rather than each spending the same token.
class TokenRefresher {
  TokenRefresher(this._dio, this._tokens);

  final Dio _dio;
  final TokenStore _tokens;
  Future<String?>? _inFlight;

  /// The new access token, or null when no refresh was possible.
  Future<String?> refresh() => _inFlight ??= _exchange().whenComplete(() {
    _inFlight = null;
  });

  Future<String?> _exchange() async {
    final refreshToken = await _tokens.readRefresh();
    if (refreshToken == null || refreshToken.isEmpty) return null;
    try {
      final response = await _dio.post<dynamic>(
        Endpoints.refresh,
        data: {'refresh_token': refreshToken},
      );
      final body = response.data;
      if (body is! Map) return null;
      final token = body['token'];
      final nextRefresh = body['refresh_token'];
      if (token is! String || nextRefresh is! String) return null;
      await _tokens.write(token);
      await _tokens.writeRefresh(nextRefresh);
      return token;
    } catch (_) {
      return null;
    }
  }
}
