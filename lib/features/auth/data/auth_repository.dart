import 'package:talk_it_out/core/models/user.dart';
import 'package:talk_it_out/features/auth/data/auth_session.dart';

abstract class AuthRepository {
  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
  });

  Future<AuthSession> login({required String email, required String password});

  /// Signs in or up with a Google ID token (`API.md` 40).
  Future<AuthSession> signInWithGoogle({required String idToken});

  Future<User> me();

  /// Asks for a long-lived refresh token for the signed-in user. Returns
  /// null when the backend does not offer one (the mock never does).
  Future<String?> issueRefreshToken();

  Future<void> logout();

  /// Permanently deletes the signed-in account (`API.md` 37). The password
  /// is required again.
  Future<void> deleteAccount({required String password});

  /// Emails a 6-digit reset code (`API.md` 38). An email with no account
  /// fails with code `no_account`; a repeat within a minute with `too_soon`.
  Future<void> requestPasswordReset({required String email});

  /// Checks the emailed code (`API.md` 48) and returns a one-time token
  /// for [confirmPasswordReset]. A wrong code says how many tries are left.
  Future<String> verifyResetCode({required String email, required String code});

  /// Changes the password while signed in (`API.md` 39). Every other
  /// session ends; returns a fresh access token for this device.
  Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Ends every session of this account, on every device (`API.md` 39).
  Future<void> logoutAll();

  /// Sets a new password with the token from [verifyResetCode].
  Future<void> confirmPasswordReset({
    required String email,
    required String resetToken,
    required String newPassword,
  });
}
