import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/features/groups/tone_hint.dart';

void main() {
  test('calm messages get no hint', () {
    for (final ok in [
      'Could we move the retro to Friday?',
      'I felt left out when the plan changed without a heads-up.',
      'The dashboard filter is hard to find.',
      'ok',
      'Thanks you all, great work!',
      'You guys did a great job on the launch.',
      "I'd hate to miss the offsite, it was just a joke.",
      'Thanks to you the demo went well.',
    ]) {
      expect(checkTone(ok), isNull, reason: ok);
    }
  });

  test('attacks, blame, absolutes and shouting get a gentle hint', () {
    expect(checkTone('This plan is stupid and useless')?.kind, 'insult');
    expect(checkTone('It is your fault the release slipped')?.kind, 'blame');
    expect(checkTone('You always ignore the design team')?.kind, 'absolute');
    expect(checkTone('Management never listens to us')?.kind, 'absolute');
    expect(checkTone('WHY IS NOBODY FIXING THIS')?.kind, 'shouting');
    expect(checkTone('Seriously???')?.kind, 'shouting');
  });
}
