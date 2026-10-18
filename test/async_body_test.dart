import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/app/theme.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/core/widgets/async_body.dart';

void main() {
  testWidgets('shows loading, empty, success, and error with retry', (
    tester,
  ) async {
    var taps = 0;

    Future<void> pump(AsyncScreenStatus status) {
      return tester.pumpWidget(
        MaterialApp(
          theme: lightTheme,
          home: Scaffold(
            body: AsyncBody(
              status: status,
              errorMessage: 'Could not load groups.',
              onRetry: () => taps++,
              empty: const Text('Nothing here'),
              child: const Text('Ready'),
            ),
          ),
        ),
      );
    }

    await pump(AsyncScreenStatus.loading);
    expect(find.bySemanticsLabel(AppStrings.loading), findsOneWidget);

    await pump(AsyncScreenStatus.empty);
    expect(find.text('Nothing here'), findsOneWidget);

    await pump(AsyncScreenStatus.success);
    expect(find.text('Ready'), findsOneWidget);

    await pump(AsyncScreenStatus.error);
    expect(find.text('Could not load groups.'), findsOneWidget);
    final button = tester.getSize(find.byType(FilledButton));
    expect(button.height, greaterThanOrEqualTo(48));
    expect(button.width, greaterThanOrEqualTo(48));
    await tester.tap(find.text(AppStrings.retry));
    expect(taps, 1);
  });
}
