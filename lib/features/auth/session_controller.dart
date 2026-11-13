import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/api/dio_provider.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/models/user.dart';
import 'package:talk_it_out/features/auth/auth_events.dart';
import 'package:talk_it_out/features/auth/data/auth_session.dart';

class SessionNotifier extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    ref.read(authEventsProvider).onUnauthorized = () {
      state = const AsyncData(null);
    };
    final token = await ref.watch(tokenStoreProvider).read();
    if (token == null || token.isEmpty) return null;
    try {
      return await ref.watch(authRepositoryProvider).me();
    } on RepositoryException {
      await ref.read(tokenStoreProvider).clear();
      return null;
    }
  }

  Future<void> login({required String email, required String password}) async {
    final session = await ref
        .read(authRepositoryProvider)
        .login(email: email, password: password);
    await _storeSession(session);
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final session = await ref
        .read(authRepositoryProvider)
        .register(name: name, email: email, password: password);
    await _storeSession(session);
  }

  /// Keeps the signed-in user's display name in step with a profile edit.
  void renamed(String name) {
    final user = state.value;
    if (user == null || user.name == name) return;
    state = AsyncData(user.copyWith(name: name));
  }

  Future<void> _storeSession(AuthSession session) async {
    final tokens = ref.read(tokenStoreProvider);
    await tokens.clear();
    await tokens.write(session.token);
    final refresh = await ref.read(authRepositoryProvider).issueRefreshToken();
    if (refresh != null) await tokens.writeRefresh(refresh);
    state = AsyncData(session.user);
  }

  /// Deletes the account on the server, then clears the local session.
  /// Throws [RepositoryException] (for example a wrong password) and keeps
  /// the user signed in when the server refuses.
  Future<void> deleteAccount({required String password}) async {
    await ref.read(authRepositoryProvider).deleteAccount(password: password);
    await ref.read(tokenStoreProvider).clear();
    state = const AsyncData(null);
  }

  Future<void> logout() async {
    try {
      await ref.read(authRepositoryProvider).logout();
    } catch (_) {
      // Local sign-out still happens if the server call fails.
    }
    await ref.read(tokenStoreProvider).clear();
    state = const AsyncData(null);
  }
}

final sessionProvider = AsyncNotifierProvider<SessionNotifier, User?>(
  SessionNotifier.new,
);
