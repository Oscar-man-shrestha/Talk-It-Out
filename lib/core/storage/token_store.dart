import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Holds the access token and, when the backend issued one, the refresh
/// token (`API.md` endpoint 35). Both live only in secure storage.
abstract class TokenStore {
  Future<String?> read();

  Future<void> write(String token);

  Future<String?> readRefresh();

  Future<void> writeRefresh(String refreshToken);

  /// Removes both tokens.
  Future<void> clear();
}

class MemoryTokenStore implements TokenStore {
  String? value;
  String? refreshValue;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String token) async => value = token;

  @override
  Future<String?> readRefresh() async => refreshValue;

  @override
  Future<void> writeRefresh(String refreshToken) async =>
      refreshValue = refreshToken;

  @override
  Future<void> clear() async {
    value = null;
    refreshValue = null;
  }
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore(this._storage);

  static const tokenKey = 'auth_token';
  static const refreshKey = 'auth_refresh_token';

  final FlutterSecureStorage _storage;

  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      // The session still lives in memory for this run.
    }
  }

  @override
  Future<String?> read() => _read(tokenKey);

  @override
  Future<void> write(String token) => _write(tokenKey, token);

  @override
  Future<String?> readRefresh() => _read(refreshKey);

  @override
  Future<void> writeRefresh(String refreshToken) =>
      _write(refreshKey, refreshToken);

  @override
  Future<void> clear() async {
    for (final key in const [tokenKey, refreshKey]) {
      try {
        await _storage.delete(key: key);
      } catch (_) {}
    }
  }
}
