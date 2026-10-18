import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:talk_it_out/app/providers.dart';
import 'package:talk_it_out/core/storage/token_store.dart';
import 'package:talk_it_out/features/auth/auth_events.dart';

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => SecureTokenStore(const FlutterSecureStorage()),
);

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
        if (error.response?.statusCode == 401) {
          await tokens.clear();
          events.onUnauthorized?.call();
        }
        handler.next(error);
      },
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});
