import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';

Future<T> runMock<T>(MockControls controls, T Function() body) async {
  if (controls.delay > Duration.zero) {
    await Future<void>.delayed(controls.delay);
  }
  if (controls.forceError) {
    throw const RepositoryException(
      code: 'unknown',
      message: AppStrings.errorGeneric,
    );
  }
  return body();
}
