import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('group-facing libraries do not import RawMessage', () {
    const groupFacingRoots = [
      'lib/features/groups',
      'lib/features/feed',
      'lib/features/auth',
      'lib/features/notifications',
      'lib/features/profile',
      'lib/core',
    ];
    final offenders = <String>[];

    void scan(Directory directory, {required bool blockReviewImport}) {
      if (!directory.existsSync()) return;
      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll('\\', '/');
        if (path.endsWith('.g.dart') || path.endsWith('.freezed.dart')) {
          continue;
        }
        final text = entity.readAsStringSync();
        final importsReview =
            text.contains('raw_message.dart') || text.contains('RawMessage');
        final importsReviewFeature = text.contains('features/review/');
        if (importsReview || (blockReviewImport && importsReviewFeature)) {
          offenders.add(path);
        }
      }
    }

    for (final root in groupFacingRoots) {
      scan(Directory(root), blockReviewImport: true);
    }
    scan(Directory('lib/app'), blockReviewImport: false);
    expect(offenders, isEmpty);
  });
}
