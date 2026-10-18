import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/mock/mock_ids.dart';
import 'package:talk_it_out/core/mock/run_mock.dart';
import 'package:talk_it_out/core/models/user.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/features/auth/data/auth_repository.dart';
import 'package:talk_it_out/features/auth/data/auth_session.dart';

class MockAuthRepository implements AuthRepository {
  MockAuthRepository(this._controls);

  /// Local mock only. Matches the sample in API.md. Not a real credential.
  static const mockPassword = 'secret123';

  final MockControls _controls;
  final Map<String, _Account> _accounts = {
    'priya@example.com': const _Account(
      user: User(id: MockIds.priya, name: 'Priya', email: 'priya@example.com'),
      password: mockPassword,
    ),
  };
  var _nextUser = 100;

  @override
  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
  }) {
    return runMock(_controls, () {
      final cleanName = name.trim();
      final cleanEmail = email.trim().toLowerCase();
      if (cleanName.isEmpty || cleanEmail.isEmpty || password.isEmpty) {
        throw const RepositoryException(
          code: 'validation',
          message: AppStrings.missingAccountFields,
        );
      }
      if (_accounts.containsKey(cleanEmail)) {
        throw const RepositoryException(
          code: 'conflict',
          message: AppStrings.emailInUse,
        );
      }
      final id = 'u$_nextUser';
      _nextUser += 1;
      final user = User(id: id, name: cleanName, email: cleanEmail);
      _accounts[cleanEmail] = _Account(user: user, password: password);
      return _session(user);
    });
  }

  @override
  Future<AuthSession> login({required String email, required String password}) {
    return runMock(_controls, () {
      final cleanEmail = email.trim().toLowerCase();
      if (cleanEmail.isEmpty || password.isEmpty) {
        throw const RepositoryException(
          code: 'validation',
          message: AppStrings.missingCredentials,
        );
      }
      final account = _accounts[cleanEmail];
      if (account == null || account.password != password) {
        throw const RepositoryException(
          code: 'validation',
          message: AppStrings.wrongLogin,
        );
      }
      return _session(account.user);
    });
  }

  @override
  Future<User> me() {
    return runMock(_controls, () => _accounts['priya@example.com']!.user);
  }

  @override
  Future<void> logout() {
    return runMock(_controls, () {});
  }

  AuthSession _session(User user) {
    return AuthSession(token: 'mock-token-${user.id}', user: user);
  }
}

class _Account {
  const _Account({required this.user, required this.password});

  final User user;
  final String password;
}
