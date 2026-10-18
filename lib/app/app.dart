import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talk_it_out/app/providers.dart';
import 'package:talk_it_out/app/router.dart';
import 'package:talk_it_out/app/theme.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';

class TalkItOutApp extends ConsumerWidget {
  const TalkItOutApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      key: ValueKey('${config.useMock}|${config.apiBaseUrl}'),
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
