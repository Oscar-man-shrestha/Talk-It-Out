import unittest

from talkitout_pipeline.text_utils import utf16_length


class Utf16LengthParityTests(unittest.TestCase):
    """Must match JavaScript str.length, which the backend's zod .max() uses."""

    def test_ascii(self):
        self.assertEqual(utf16_length("hello"), 5)

    def test_empty(self):
        self.assertEqual(utf16_length(""), 0)

    def test_emoji_counts_as_two_units(self):
        self.assertEqual(utf16_length("🎉"), 2)  # Python len() would say 1

    def test_bmp_character_counts_as_one(self):
        self.assertEqual(utf16_length("é"), 1)
        self.assertEqual(utf16_length("中"), 1)

    def test_emoji_zwj_family(self):
        # U+1F468 x2 + U+1F467 x2 + 3 ZWJ = 4*2 + 3 = 11 units (JS parity)
        family = "\U0001F468\u200D\U0001F469\u200D\U0001F467\u200D\U0001F466"
        self.assertEqual(utf16_length(family), 11)

    def test_lone_surrogate_counts_as_one_like_js(self):
        self.assertEqual(utf16_length("\uD83D"), 1)

    def test_mixed_text(self):
        self.assertEqual(utf16_length("a🎉b"), 4)


if __name__ == "__main__":
    unittest.main()
