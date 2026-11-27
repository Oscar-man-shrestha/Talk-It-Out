import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/app/app.dart';
import 'package:talk_it_out/app/router.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/api/dio_provider.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/storage/token_store.dart';
import 'package:talk_it_out/core/ui/page_padding.dart';

/// Every main screen at phone, tablet and desktop sizes, and with large
/// text on phones, must lay out without overflow or other layout errors.
const _signedInRoutes = [
  '/groups',
  '/groups/new',
  '/groups/g1',
  '/groups/g1/info',
  '/groups/g1/members',
  '/groups/g1/mine',
  '/groups/g2',
  '/groups/g2/review',
  '/groups/g2/insights',
  '/premium',
  '/feed',
  '/feed/new',
  '/feed/interests',
  '/feed/p4',
  '/feed/p5',
  '/notifications',
  '/profile',
  '/settings',
  '/starred',
  '/chat-theme',
  '/people/u2',
  '/legal/terms',
];

const _signedOutRoutes = ['/login', '/register', '/forgot-password'];

class _Device {
  const _Device(this.name, this.size, [this.textScale = 1.0]);
  final String name;
  final Size size;
  final double textScale;
}

const _devices = [
  _Device('small phone', Size(320, 568)),
  _Device('phone', Size(390, 844)),
  _Device('phone, large text', Size(390, 844), 1.5),
  _Device('tablet', Size(768, 1024)),
  _Device('tablet landscape', Size(1024, 768)),
  _Device('desktop', Size(1440, 900)),
];

Future<List<String>> _layoutErrors(
  WidgetTester tester,
  _Device device,
  List<String> routes, {
  required bool signedIn,
}) async {
  final errors = <String>[];
  final previous = FlutterError.onError;
  String current = '';
  FlutterError.onError = (details) {
    final text = details.exceptionAsString().split('\n').first;
    final where = RegExp(r'lib/[\w/]+\.dart:\d+')
        .allMatches(details.toString())
        .map((m) => m.group(0))
        .toSet()
        .join(' ');
    errors.add('${device.name} $current: $text $where');
  };
  addTearDown(() => FlutterError.onError = previous);

  tester.view.physicalSize = device.size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = device.textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final token = MemoryTokenStore()..value = signedIn ? 'mock-token' : null;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStoreProvider.overrideWithValue(token),
        mockControlsProvider.overrideWithValue(
          MockControls(delay: Duration.zero),
        ),
      ],
      child: const TalkItOutApp(),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(TalkItOutApp)),
  );
  final GoRouter router = container.read(routerProvider);
  for (final route in routes) {
    current = route;
    router.go(route);
    await tester.pumpAndSettle();
  }
  FlutterError.onError = previous;
  await tester.pumpWidget(const SizedBox());
  return errors;
}

/// Real Roboto metrics (the test font draws every letter as a wide square,
/// which reports overflows that never happen on a device).
Future<void> _loadRoboto() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  if (!dir.existsSync()) return;
  final loader = FontLoader('Roboto');
  for (final file in dir.listSync().whereType<File>()) {
    final name = file.uri.pathSegments.last;
    if (name.startsWith('Roboto-') && name.endsWith('.ttf')) {
      final bytes = file.readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
  }
  await loader.load();
}

/// The app's bundled font, so layout is measured with real metrics.
Future<void> _loadInter() async {
  final loader = FontLoader('Inter');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final file = File('assets/fonts/inter/Inter-$weight.ttf');
    if (file.existsSync()) {
      loader.addFont(
        Future.value(ByteData.sublistView(file.readAsBytesSync())),
      );
    }
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    await _loadRoboto();
    await _loadInter();
  });

  test('page padding is continuous and lines content up', () {
    expect(pageHPad(320), 12);
    expect(pageHPad(599), 12);
    expect(pageHPad(600), 20);
    expect(pageHPad(900), 20);
    expect(pageHPad(1440), 290);
    // No jump where the centred column takes over.
    expect((pageHPad(901) - pageHPad(899)).abs(), lessThan(1));
  });

  for (final device in _devices) {
    testWidgets('signed-in screens fit: ${device.name}', (tester) async {
      final errors = await _layoutErrors(
        tester,
        device,
        _signedInRoutes,
        signedIn: true,
      );
      expect(errors, isEmpty, reason: errors.join('\n'));
    });

    testWidgets('signed-out screens fit: ${device.name}', (tester) async {
      final errors = await _layoutErrors(
        tester,
        device,
        _signedOutRoutes,
        signedIn: false,
      );
      expect(errors, isEmpty, reason: errors.join('\n'));
    });
  }
}
