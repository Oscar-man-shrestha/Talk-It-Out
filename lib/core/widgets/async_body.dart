import 'package:flutter/material.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';

enum AsyncScreenStatus { loading, empty, error, success }

/// Shared loading, empty, error-with-retry, and success body for screens.
class AsyncBody extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.status,
    required this.onRetry,
    required this.empty,
    required this.child,
    this.errorMessage,
  });

  final AsyncScreenStatus status;
  final VoidCallback onRetry;
  final Widget empty;
  final Widget child;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case AsyncScreenStatus.loading:
        return const _LoadingBody();
      case AsyncScreenStatus.empty:
        return empty;
      case AsyncScreenStatus.error:
        return _ErrorBody(
          message: errorMessage ?? AppStrings.errorGeneric,
          onRetry: onRetry,
        );
      case AsyncScreenStatus.success:
        return child;
    }
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppStrings.loading,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text(AppStrings.retry),
            ),
          ],
        ),
      ),
    );
  }
}
