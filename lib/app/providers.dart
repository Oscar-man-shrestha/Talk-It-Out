import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talk_it_out/app/config.dart';

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);
