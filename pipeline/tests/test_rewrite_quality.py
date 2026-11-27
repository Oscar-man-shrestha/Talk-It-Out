"""Run 114: echo retry, output capitalisation, prompt rules, stemmed relevance."""

import unittest

from talkitout_pipeline import scoring
from talkitout_pipeline.errors import OutputValidationError
from talkitout_pipeline.rewrite import SYSTEM_PROMPT, looks_unpolished

from .test_rewrite import make_service


class EchoRetryTests(unittest.TestCase):
    ROUGH = "honestly the spinner takes ages, it's unusable"

    def test_rough_message_echoed_gets_one_more_try(self):
        better = "The spinner takes a long time and is hard to use."
        service, adapter = make_service([self.ROUGH, better])
        outcome = service.rewrite(self.ROUGH, "Dashboard improvements")
        self.assertEqual(len(adapter.calls), 2)
        self.assertEqual(outcome.rewritten_text, better)
        self.assertFalse(outcome.unchanged)
        note = adapter.calls[1]["messages"][-1]["content"]
        self.assertIn("word for word", note)
        self.assertNotIn("spinner", note)  # the note never carries message text

    def test_echo_again_is_accepted_as_the_models_decision(self):
        service, adapter = make_service([self.ROUGH])
        outcome = service.rewrite(self.ROUGH, "Dashboard improvements")
        self.assertEqual(len(adapter.calls), 2)
        self.assertTrue(outcome.unchanged)

    def test_invalid_second_try_keeps_the_valid_first_output(self):
        service, _ = make_service([self.ROUGH, ""])
        outcome = service.rewrite(self.ROUGH, "Dashboard improvements")
        self.assertEqual(outcome.rewritten_text, "Honestly the spinner takes ages, it's unusable")

    def test_polished_message_echoed_is_not_retried(self):
        original = "Could you please review my pull request today?"
        service, adapter = make_service([original])
        outcome = service.rewrite(original, "Dashboard improvements")
        self.assertEqual(len(adapter.calls), 1)
        self.assertTrue(outcome.unchanged)

    def test_failed_check_still_fails_the_job_after_one_retry(self):
        service, adapter = make_service(["The bug was fixed."])
        with self.assertRaises(OutputValidationError) as ctx:
            service.rewrite("nobody fixed the bug", "agenda")
        self.assertEqual(ctx.exception.code, "intent_not_preserved")
        self.assertEqual(len(adapter.calls), 2)


class LooksUnpolishedTests(unittest.TestCase):
    def test_rough_signs(self):
        for text in ("the build broke", "this is useless", "Why is it BROKEN again",
                     "who did this??", "Ugh, again.", "I'm sick of this."):
            self.assertTrue(looks_unpolished(text), text)

    def test_polished_text(self):
        for text in ("Could you review the JSON export?", "Thanks, it works now.",
                     "The API returns 500 on login."):
            self.assertFalse(looks_unpolished(text), text)


class CapitalisationTests(unittest.TestCase):
    def test_first_letter_is_capitalised(self):
        service, _ = make_service(["please fix the export bug."])
        outcome = service.rewrite("fix the export bug now!!", "agenda")
        self.assertEqual(outcome.rewritten_text, "Please fix the export bug.")

    def test_non_letter_start_untouched(self):
        service, _ = make_service(["3 charts fail to load."])
        outcome = service.rewrite("3 charts are broken!!", "agenda")
        self.assertEqual(outcome.rewritten_text, "3 charts fail to load.")


class PromptRuleTests(unittest.TestCase):
    def test_request_direction_and_firmness_rules(self):
        self.assertIn('"stop doing X" stays a request to stop doing X', SYSTEM_PROMPT)
        self.assertIn("Keep criticism firm", SYSTEM_PROMPT)
        self.assertIn('"nobody" stays nobody', SYSTEM_PROMPT)

    def test_examples_are_labelled_as_examples(self):
        self.assertIn("never copy their content", SYSTEM_PROMPT)


class StemmedRelevanceTests(unittest.TestCase):
    def test_word_forms_match(self):
        score, label = scoring.relevance("We should improve the dashboards.",
                                         "Dashboard improvements")
        self.assertEqual((score, label), (1.0, "relevant"))

    def test_filler_words_do_not_count(self):
        # "making" is filler, so only "nlp" and "notes" are the topic.
        score, _ = scoring.relevance("The notes are late.", "Making NLP notes")
        self.assertEqual(score, 0.5)

    def test_unrelated_message_is_off_topic(self):
        _, label = scoring.relevance("Lunch is at noon.", "Dashboard improvements")
        self.assertEqual(label, "off_topic")

    def test_agenda_of_only_filler_words_is_neutral(self):
        self.assertEqual(scoring.relevance("Anything.", "the and of"), (0.5, "borderline"))

    def test_stem_examples(self):
        self.assertEqual(scoring.stem("improvements"), scoring.stem("improve"))
        self.assertEqual(scoring.stem("dashboards"), "dashboard")
        self.assertEqual(scoring.stem("notes"), "note")
        self.assertEqual(scoring.stem("class"), "class")


if __name__ == "__main__":
    unittest.main()
