import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/app/app.dart';
import 'package:talk_it_out/core/api/dio_provider.dart';
import 'package:talk_it_out/core/storage/token_store.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';

void main() {
  testWidgets('signed-out app opens on log in', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [tokenStoreProvider.overrideWithValue(MemoryTokenStore())],
        child: const TalkItOutApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.loginTitle), findsWidgets);
    expect(
      find.widgetWithText(FilledButton, AppStrings.loginAction),
      findsOneWidget,
    );
  });
}
