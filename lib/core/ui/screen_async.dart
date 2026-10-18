import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/core/widgets/async_body.dart';

AsyncScreenStatus asyncStatus<T>(AsyncValue<T> value, {required bool isEmpty}) {
  if (value.isLoading && !value.hasValue) return AsyncScreenStatus.loading;
  if (value.hasError && !value.hasValue) return AsyncScreenStatus.error;
  if (value.hasValue && isEmpty) return AsyncScreenStatus.empty;
  return AsyncScreenStatus.success;
}

String? errorText(Object? error) {
  if (error is RepositoryException) return error.message;
  if (error == null) return null;
  return AppStrings.errorGeneric;
}
