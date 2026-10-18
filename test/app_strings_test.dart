import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/app/config.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';

void main() {
  test('anonymity copy matches the hard rules', () {
    expect(AppStrings.anonymousUser, 'Anonymous user');
    expect(AppStrings.anonymousCheckbox, 'Anonymous message');
    expect(
      AppStrings.anonymousDisclosure,
      'Anonymous messages are hidden from the group but visible to the controller.',
    );
    expect(AppStrings.rewriteUnavailable, 'Rewrite unavailable');
  });

  test('rejection copy has no reason', () {
    expect(
      AppStrings.messageRejected('Making NLP notes'),
      'Your message in Making NLP notes was rejected.',
    );
    expect(
      AppStrings.messageRejected('Making NLP notes'),
      isNot(contains('reason')),
    );
  });

  test('environment defaults to mock data', () {
    final config = AppConfig.fromEnvironment();
    expect(config.useMock, isTrue);
    expect(config.apiBaseUrl, 'http://localhost:3000');
  });
}
