import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/app/app.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/api/dio_provider.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/storage/token_store.dart';

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first));

Future<void> _pumpSignedOut(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
        mockControlsProvider.overrideWithValue(
          MockControls(delay: Duration.zero),
        ),
      ],
      child: const TalkItOutApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('legal pages open without signing in', (tester) async {
    await _pumpSignedOut(tester);
    for (final (path, title) in const [
      ('privacy', 'Privacy Policy'),
      ('terms', 'Terms of Use'),
      ('delete-account', 'Delete your Talk It Out account'),
    ]) {
      _router(tester).go('/legal/$path');
      await tester.pumpAndSettle();
      expect(
        _router(tester).routerDelegate.currentConfiguration.uri.path,
        '/legal/$path',
      );
      expect(find.text(title), findsOneWidget);
    }
  });

  testWidgets('Register links to the terms', (tester) async {
    await _pumpSignedOut(tester);
    _router(tester).go('/register');
    await tester.pumpAndSettle();
    final link = find.byKey(const ValueKey('register-terms'));
    await tester.ensureVisible(link);
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.text('Terms of Use'), findsOneWidget);
  });

  test('app and server show the same legal text', () {
    for (final name in ['privacy', 'terms', 'delete-account']) {
      expect(
        File('assets/legal/$name.md').readAsStringSync(),
        File('backend/legal/$name.md').readAsStringSync(),
        reason: name,
      );
    }
  });
}
