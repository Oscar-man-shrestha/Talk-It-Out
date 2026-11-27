import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/features/discovery/data/interest_catalog.dart';
import 'package:talk_it_out/features/discovery/interest_icons.dart';

void main() {
  test('the app lists the same 30 interests as the server', () {
    final source = File('backend/src/nlp/topics.ts').readAsStringSync();
    final server = RegExp(
      r"id: '([a-z_]+)',\s+label: '([^']*)',\s+icon: '([a-z_]+)'",
    ).allMatches(source).map((m) => '${m[1]}|${m[2]}|${m[3]}').toList();
    final app = [
      for (final o in kInterestCatalog) '${o.id}|${o.label}|${o.icon}',
    ];
    expect(app, hasLength(30));
    expect(app, server);
  });

  test('every interest has a vector icon and no emoji', () {
    for (final o in kInterestCatalog) {
      expect(knownInterestIcons, contains(o.icon), reason: o.id);
      expect(interestIcon(o.icon), isNot(Icons.label_outline));
      // Labels and blurbs are plain text.
      expect(
        RegExp(
          r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
          unicode: true,
        ).hasMatch(o.label + o.blurb),
        isFalse,
        reason: o.id,
      );
    }
    expect(interestIcon('unknown'), Icons.label_outline);
  });

  test('demo tagging knows every interest', () {
    expect(kDemoInterestKeywords.keys.toSet(), {
      for (final o in kInterestCatalog) o.id,
    });
  });
}
