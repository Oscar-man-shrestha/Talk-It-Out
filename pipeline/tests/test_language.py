import unittest

from talkitout_pipeline.language import looks_like_english


class LanguageGateTests(unittest.TestCase):
    def test_plain_english(self):
        self.assertTrue(looks_like_english("Can we move the deadline to Friday?"))

    def test_english_without_stopwords_but_short(self):
        self.assertTrue(looks_like_english("ok"))

    def test_non_latin_script_rejected(self):
        self.assertFalse(looks_like_english("Пожалуйста, проверьте отчёт"))
        self.assertFalse(looks_like_english("こんにちは、レビューをお願いします"))
        self.assertFalse(looks_like_english("مرحبا، هل يمكنني المساعدة"))

    def test_latin_but_not_english_rejected(self):
        self.assertFalse(looks_like_english("hola como estas te veo luego"))

    def test_latin_letters_with_diacritics_are_latin(self):
        self.assertTrue(looks_like_english("Please send the résumé to José"))

    def test_mostly_emoji_passes_gate(self):
        # No letter signal either way: the blank/quality checks handle it.
        self.assertTrue(looks_like_english("🎉🎉🎉"))

    def test_numbers_only_passes_gate(self):
        self.assertTrue(looks_like_english("12345"))

    def test_mixed_script_majority_non_latin(self):
        self.assertFalse(looks_like_english("hello Привет пока до свидания"))


class FalseRejectionRegressionTests(unittest.TestCase):
    """Ordinary English that must not be rejected for lacking stopwords."""

    def test_content_words_without_stopwords(self):
        self.assertTrue(looks_like_english("Meeting starts tomorrow"))

    def test_common_polite_request(self):
        self.assertTrue(looks_like_english("Please submit the report today"))

    def test_negation_message(self):
        self.assertTrue(looks_like_english("I cannot attend the meeting"))

    def test_deadline_message(self):
        self.assertTrue(looks_like_english("The deadline is Monday"))

    def test_ok(self):
        self.assertTrue(looks_like_english("OK"))

    def test_ok_lowercase(self):
        self.assertTrue(looks_like_english("ok"))

    def test_empty_and_whitespace_only(self):
        # Documented policy: no signal, passes; blankness is the
        # caller's concern (blank outputs are rejected later, and the
        # backend refuses blank submissions).
        self.assertTrue(looks_like_english(""))
        self.assertTrue(looks_like_english("   \n\t  "))

    def test_clearly_non_english_still_rejected(self):
        self.assertFalse(looks_like_english("Пожалуйста, проверьте отчёт до пятницы"))
        self.assertFalse(looks_like_english("Por favor envíame el informe antes del viernes"))
        self.assertFalse(looks_like_english("このレポートを確認してください"))

    def test_very_short_ambiguous_gets_benefit_of_doubt(self):
        # Documented policy: fewer than three words cannot be classified
        # reliably, so they pass. A single foreign word may slip through;
        # the gate refuses clearly unsupported languages, not typos.
        self.assertTrue(looks_like_english("hola"))
        self.assertTrue(looks_like_english("???"))

    def test_mixed_english_sentence_with_foreign_word(self):
        self.assertTrue(looks_like_english("The report está ready, please check"))

    def test_long_latin_text_with_zero_english_signal_rejected(self):
        self.assertFalse(looks_like_english("quiero saber cuando vamos a empezar"))


if __name__ == "__main__":
    unittest.main()
