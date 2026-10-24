"""Character counting that matches the backend exactly.

The backend enforces PIPELINE_MAX_INPUT_CHARS / PIPELINE_MAX_OUTPUT_CHARS
with zod's string .max(), which counts JavaScript string length — UTF-16
code units, not Unicode code points. A non-BMP character such as an emoji
is TWO units for the backend and ONE for Python's len(), so the worker
must count the same way or a rewrite accepted here could be rejected
there (422, which counts as a failed attempt).
"""


def utf16_length(text: str) -> int:
    """Length in UTF-16 code units, identical to JavaScript str.length."""
    total = 0
    for ch in text:
        total += 2 if ord(ch) > 0xFFFF else 1
    return total
