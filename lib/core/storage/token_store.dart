import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class TokenStore {
  Future<String?> read();

  Future<void> write(String token);

  Future<void> clear();
}

class MemoryTokenStore implements TokenStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String token) async => value = token;

  @override
  Future<void> clear() async => value = null;
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore(this._storage);

  static const tokenKey = 'auth_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: tokenKey);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String token) async {
    try {
      await _storage.write(key: tokenKey, value: token);
    } catch (_) {
      // The session still lives in memory for this run.
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: tokenKey);
    } catch (_) {}
  }
}
