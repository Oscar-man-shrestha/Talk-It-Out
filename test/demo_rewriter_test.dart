import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/features/groups/demo_rewriter.dart';

void main() {
  test('calms harsh messages and keeps the facts', () {
    expect(
      demoRewrite(
        "this is the third time the build broke because SOMEONE didn't run tests. pathetic.",
      ),
      "This is the third time the build broke because someone didn't run tests. Disappointing.",
    );
    expect(
      demoRewrite(
        'Your estimates are always wrong and it makes us look stupid in front of the client',
      ),
      'Your estimates are always wrong and it makes us look unprepared in front of the client.',
    );
    expect(
      demoRewrite(
        'Can someone explain why my PR has been ignored for a week???',
      ),
      'Can someone explain why my PR has been ignored for a week?',
    );
    expect(
      demoRewrite('honestly the new process is a joke, who even approved this'),
      'The new process is not working, I would like to understand how this was approved.',
    );
    expect(
      demoRewrite('fix the login bug today!!!'),
      'Please fix the login bug today!',
    );
  });

  test('leaves polite messages alone apart from tidying', () {
    expect(
      demoRewrite('Thanks for the help yesterday, the fix worked.'),
      'Thanks for the help yesterday, the fix worked.',
    );
    expect(
      demoRewrite('Can we add export to CSV?'),
      'Can we add export to CSV?',
    );
    // Spaces before punctuation are tidied, never replaced by placeholders.
    expect(demoRewrite('ok , that works !'), 'Ok, that works!');
  });
}
