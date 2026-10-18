import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/app/config.dart';
import 'package:talk_it_out/app/providers.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/features/groups/data/api_group_repository.dart';
import 'package:talk_it_out/features/groups/data/mock_group_repository.dart';

void main() {
  test('USE_MOCK selects the mock repository', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(groupRepositoryProvider), isA<MockGroupRepository>());
  });

  test('USE_MOCK false selects the API repository', () {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(useMock: false, apiBaseUrl: 'http://localhost:3000'),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(groupRepositoryProvider), isA<ApiGroupRepository>());
  });
}
