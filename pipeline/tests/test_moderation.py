"""Moderation signals (moderation.py) and how the rewrite uses them."""

import unittest

from talkitout_pipeline import moderation as m
from talkitout_pipeline.errors import OutputValidationError

from .test_rewrite import make_service


class DetectTests(unittest.TestCase):
    def test_categories(self):
        cases = {
            "you guys are total idiots": [m.ABUSIVE],
            "this is fucking broken": [m.PROFANITY],
            "all immigrants are criminals": [m.HATE],
            "women can't do backend work, give it to someone competent": [m.HATE],
            "a woman is not technical enough to lead": [m.HATE],
            "go back to your country": [m.HATE],
            "I will kill you if the deploy fails again": [m.THREAT],
            "honestly I want to die, this job is crushing me": [m.SELF_HARM],
        }
        for text, expected in cases.items():
            got = m.detect(text)
            for flag in expected:
                self.assertIn(flag, got, text)

    def test_disguised_words_are_caught(self):
        for text in ("you are an 1d10t", "f.u.c.k this release", "what a fuuuucking mess", "$hit design"):
            self.assertTrue(m.detect(text), text)

    def test_criticism_of_things_is_not_abuse(self):
        for text in (
            "the dashboard is useless and slow",
            "this release was a disaster for support",
            "I disagree with the decision to cut testing",
            "Could you please review my pull request?",
            "I'm late bc of traffic",
            "The class starts at 9",
        ):
            self.assertEqual(m.detect(text), [], text)

    def test_rewrite_keeping_a_group_attack_is_offensive(self):
        self.assertTrue(m.offensive_left("Women cannot perform backend work; give it to someone else."))
        self.assertTrue(m.offensive_left("Women may not be suited for backend work."))
        self.assertFalse(m.offensive_left("Please give the backend work to the most experienced person."))

    def test_flags_have_a_stable_order(self):
        self.assertEqual(
            m.detect("you idiots, I will kill you, fuck this"),
            [m.THREAT, m.ABUSIVE, m.PROFANITY],
        )

    def test_offensive_left_ignores_calm_text(self):
        self.assertFalse(m.offensive_left("I am very frustrated that the login is still broken."))
        self.assertTrue(m.offensive_left("Please fix the damn login, you morons."))
        # Saying someone is struggling is not offensive.
        self.assertFalse(m.offensive_left("I am struggling and feel like I want to die some days."))


class RefusalTests(unittest.TestCase):
    def test_refusals(self):
        for out in (
            "I can't help with that.",
            "I'm sorry, but I cannot assist with this request.",
            "As an AI, I won't rewrite hateful content.",
        ):
            self.assertTrue(m.is_refusal(out, "you are all idiots"), out)

    def test_apologies_and_senders_own_words_are_not_refusals(self):
        self.assertFalse(m.is_refusal("Sorry, I can't join the call today.", "cant join the call sry"))
        self.assertFalse(
            m.is_refusal("I can't help with the release this week.", "i cant help with the release this week"),
        )


class RewriteFlowTests(unittest.TestCase):
    def test_flags_are_reported_for_the_original(self):
        service, _ = make_service(["Please fix the login; I am frustrated it is still broken."])
        outcome = service.rewrite("you idiots fix the fucking login", "Launch")
        self.assertEqual(outcome.moderation_flags, (m.ABUSIVE, m.PROFANITY))

    def test_abuse_kept_in_rewrite_gets_one_correction(self):
        service, adapter = make_service(
            ["Fix the login, you idiots.", "Please fix the login; it is still broken."]
        )
        outcome = service.rewrite("fix the login you idiots", "Launch")
        self.assertEqual(outcome.rewritten_text, "Please fix the login; it is still broken.")
        self.assertEqual(len(adapter.calls), 2)
        note = adapter.calls[1]["messages"][-1]["content"]
        self.assertIn("offensive", note)
        self.assertNotIn("idiots", note)  # notes never carry message text

    def test_abuse_kept_twice_fails_honestly(self):
        service, _ = make_service(["Fix it, you idiots."])
        with self.assertRaises(OutputValidationError) as ctx:
            service.rewrite("fix it you idiots", "Launch")
        self.assertEqual(ctx.exception.code, "abusive_language_kept")

    def test_refusal_gets_one_correction_then_fails(self):
        service, adapter = make_service(["I can't help with that.", "The release is late again and I am upset."])
        outcome = service.rewrite("release late AGAIN, you clowns", "Launch")
        self.assertEqual(len(adapter.calls), 2)
        self.assertIn("upset", outcome.rewritten_text)
        service, _ = make_service(["I can't help with that."])
        with self.assertRaises(OutputValidationError) as ctx:
            service.rewrite("you clowns broke the release", "Launch")
        self.assertEqual(ctx.exception.code, "model_refused")

    def test_abuse_only_never_reaches_the_model(self):
        service, adapter = make_service(["should not be called"])
        with self.assertRaises(OutputValidationError) as ctx:
            service.rewrite("you idiots", "Launch")
        self.assertEqual(ctx.exception.code, "abuse_only")
        self.assertEqual(adapter.calls, [])
        self.assertTrue(m.has_substance("you idiots fix the login"))
        self.assertFalse(m.has_substance("f***ing morons!!"))

    def test_copied_context_line_is_stripped(self):
        service, _ = make_service(["Group topic: Launch\n\nPlease fix the login."])
        outcome = service.rewrite("fix the login!!", "Launch")
        self.assertEqual(outcome.rewritten_text, "Please fix the login.")

    def test_rewrite_may_not_mention_the_attacked_group(self):
        service, adapter = make_service([
            "Women may face challenges in backend work.",
            "Please assign the backend work to the most experienced person.",
        ])
        outcome = service.rewrite("women can't do backend work, give it to someone competent", "Launch")
        self.assertEqual(len(adapter.calls), 2)
        self.assertNotIn("omen", outcome.rewritten_text)
        service, _ = make_service(["Women may face challenges in backend work."])
        with self.assertRaises(OutputValidationError) as ctx:
            service.rewrite("women can't do backend work", "Launch")
        self.assertEqual(ctx.exception.code, "hate_speech_kept")
        # A group named neutrally, with no attack, is fine.
        self.assertEqual(m.targeted_groups("Our women in tech circle meets Friday"), set())

    def test_dropping_a_hateful_negation_is_allowed(self):
        service, _ = make_service(["Please give the backend work to the most experienced person."])
        outcome = service.rewrite("women can't do backend work, give it to someone competent", "Launch")
        self.assertIn(m.HATE, outcome.moderation_flags)

    def test_prompt_tells_the_model_to_drop_abuse_and_hate(self):
        from talkitout_pipeline.rewrite import SYSTEM_PROMPT

        self.assertIn("threats completely", SYSTEM_PROMPT)
        self.assertIn("attacks people for who they are", SYSTEM_PROMPT)


if __name__ == "__main__":
    unittest.main()
