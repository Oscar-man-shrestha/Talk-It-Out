import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/app/app.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/api/dio_provider.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/core/storage/token_store.dart';
import 'package:talk_it_out/features/auth/data/mock_auth_repository.dart';
import 'package:talk_it_out/features/auth/saved_accounts.dart';
import 'package:talk_it_out/features/auth/session_controller.dart';

void main() {
  test('emails are masked for the account chooser', () {
    expect(
      const SavedAccount(name: 'Priya', email: 'priya@example.com').maskedEmail,
      'pr***@example.com',
    );
    expect(
      const SavedAccount(name: 'A', email: 'a@x.io').maskedEmail,
      'a***@x.io',
    );
  });

  testWidgets('after signing out: Continue as, password still required', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
          mockControlsProvider.overrideWithValue(
            MockControls(delay: Duration.zero),
          ),
          savedAccountsStorageProvider.overrideWithValue(null),
        ],
        child: const TalkItOutApp(),
      ),
    );
    await tester.pumpAndSettle();
    // First visit: nobody to continue as.
    expect(find.text('Continue as'), findsNothing);

    final loginFields = find.byType(TextField);
    await tester.enterText(loginFields.at(0), MockAuthRepository.mockEmail);
    await tester.enterText(loginFields.at(1), MockAuthRepository.mockPassword);
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.loginAction));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(NavigationBar)),
    );
    await container.read(sessionProvider.notifier).logout();
    await tester.pumpAndSettle();

    // Back on login: the account is offered, nothing is filled in.
    expect(find.text('Continue as'), findsOneWidget);
    final fields = find.byType(TextField);
    expect(tester.widget<TextField>(fields.at(0)).controller!.text, isEmpty);
    expect(tester.widget<TextField>(fields.at(1)).controller!.text, isEmpty);

    await tester.tap(
      find.byKey(
        const ValueKey('saved-account-${MockAuthRepository.mockEmail}'),
      ),
    );
    await tester.pump();
    expect(
      tester.widget<TextField>(fields.at(0)).controller!.text,
      MockAuthRepository.mockEmail,
    );
    expect(tester.widget<TextField>(fields.at(1)).controller!.text, isEmpty);

    // Removing it from this device.
    await tester.tap(
      find.byKey(
        const ValueKey('forget-account-${MockAuthRepository.mockEmail}'),
      ),
    );
    await tester.pump();
    expect(find.text('Continue as'), findsNothing);
    expect(tester.widget<TextField>(fields.at(0)).controller!.text, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
}
