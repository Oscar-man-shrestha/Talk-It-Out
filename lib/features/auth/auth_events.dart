import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthEvents {
  void Function()? onUnauthorized;
}

final authEventsProvider = Provider<AuthEvents>((ref) => AuthEvents());
