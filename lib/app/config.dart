/// Runtime config from `--dart-define`. Mock is the default so the app
/// runs before a backend exists.
class AppConfig {
  const AppConfig({
    required this.useMock,
    required this.apiBaseUrl,
    this.googleClientId = '',
  });

  final bool useMock;
  final String apiBaseUrl;

  /// Web OAuth client id for Sign in with Google; empty hides the button
  /// in live builds.
  final String googleClientId;

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      useMock: bool.fromEnvironment('USE_MOCK', defaultValue: true),
      apiBaseUrl: String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://localhost:3000',
      ),
      googleClientId: String.fromEnvironment('GOOGLE_CLIENT_ID'),
    );
  }
}
