/// Runtime config from `--dart-define`. Mock is the default so the app
/// runs before a backend exists.
class AppConfig {
  const AppConfig({
    required this.useMock,
    required this.apiBaseUrl,
    this.googleClientId = '',
    this.revenuecatAppleKey = '',
    this.revenuecatGoogleKey = '',
  });

  final bool useMock;
  final String apiBaseUrl;

  /// Web OAuth client id for Sign in with Google; empty hides the button
  /// in live builds.
  final String googleClientId;

  /// RevenueCat public SDK keys for Premium (`docs/PREMIUM_PLAN.md`).
  /// Empty: no store purchase in that build.
  final String revenuecatAppleKey;
  final String revenuecatGoogleKey;

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      useMock: bool.fromEnvironment('USE_MOCK', defaultValue: true),
      apiBaseUrl: String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://localhost:3000',
      ),
      googleClientId: String.fromEnvironment('GOOGLE_CLIENT_ID'),
      revenuecatAppleKey: String.fromEnvironment('REVENUECAT_APPLE_KEY'),
      revenuecatGoogleKey: String.fromEnvironment('REVENUECAT_GOOGLE_KEY'),
    );
  }
}
