/// Runtime config from `--dart-define`. Mock is the default so the app
/// runs before a backend exists.
class AppConfig {
  const AppConfig({required this.useMock, required this.apiBaseUrl});

  final bool useMock;
  final String apiBaseUrl;

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      useMock: bool.fromEnvironment('USE_MOCK', defaultValue: true),
      apiBaseUrl: String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://localhost:3000',
      ),
    );
  }
}
