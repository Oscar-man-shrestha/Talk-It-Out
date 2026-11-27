import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/app/theme.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/core/ui/double_tap_like.dart';
import 'package:talk_it_out/core/ui/motion.dart';
import 'package:talk_it_out/core/ui/skeleton.dart';
import 'package:talk_it_out/features/auth/auth_frame.dart';

Widget _app(Widget child) => MaterialApp(
  theme: lightTheme,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('double tap likes once; a liked card is not unliked', (
    tester,
  ) async {
    var likes = 0;
    Future<void> doubleTap() async {
      await tester.tap(find.text('card'));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(find.text('card'));
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(
      _app(
        DoubleTapLike(
          liked: false,
          onLike: () => likes++,
          child: const SizedBox(width: 200, height: 120, child: Text('card')),
        ),
      ),
    );
    await doubleTap();
    expect(likes, 1);

    await tester.pumpWidget(
      _app(
        DoubleTapLike(
          liked: true,
          onLike: () => likes++,
          child: const SizedBox(width: 200, height: 120, child: Text('card')),
        ),
      ),
    );
    await doubleTap();
    expect(likes, 1, reason: 'double tap never unlikes');
  });

  testWidgets('Reveal ends fully visible', (tester) async {
    await tester.pumpWidget(_app(const Reveal(index: 3, child: Text('hi'))));
    await tester.pumpAndSettle();
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('hi'), matching: find.byType(Opacity)),
    );
    expect(opacity.opacity, 1);
  });

  testWidgets('AnimatedCount shows the new value', (tester) async {
    await tester.pumpWidget(_app(const AnimatedCount(3)));
    await tester.pumpWidget(_app(const AnimatedCount(4)));
    await tester.pumpAndSettle();
    expect(find.text('4'), findsOneWidget);
    expect(find.text('3'), findsNothing);
  });

  testWidgets('skeleton loading is announced as Loading', (tester) async {
    await tester.pumpWidget(_app(const SkeletonList(count: 2)));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.bySemanticsLabel(AppStrings.loading), findsOneWidget);
  });

  testWidgets('wide screens show the brand panel beside the form', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(const AuthFrame(form: Text('form'))));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.heroTitle), findsOneWidget);
    expect(find.text(AppStrings.heroFootnote), findsOneWidget);
    expect(find.text('form'), findsOneWidget);
  });

  testWidgets('phones show the form only, over the scene', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(const AuthFrame(form: Text('form'))));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.heroTitle), findsNothing);
    expect(find.text('form'), findsOneWidget);
  });
}
