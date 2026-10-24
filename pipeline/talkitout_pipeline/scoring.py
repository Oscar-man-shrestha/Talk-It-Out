"""Deterministic, documented scoring — explicitly NOT model confidence.

The backend requires a score and label on every successful result
(contract §3). The method here is a fixed, testable heuristic, not a
calibrated probability, and relevance stays advisory (contract §3):
low relevance never hides or rejects a message. The method and its
limits are documented in README.md; thresholds are provisional and
tracked in LOGS.md Open Decisions (D3/D18).

intent_preservation_score
    1.0, minus penalties: 0.25 if the rewrite is under 40% of the
    original's UTF-16 length (possible content loss), 0.2 per digit
    sequence present in the original but absent from the rewrite
    (capped at 0.4). Clamped to [0, 1], rounded to 2 decimals.

relevance_score
    The fraction of the group agenda's word stems that appear in the
    rewrite (bag-of-words overlap). Label: >= 0.50 relevant,
    >= 0.15 borderline, else off_topic. Uncalibrated by design.
"""

from __future__ import annotations

import re

from .text_utils import utf16_length

_DIGITS_RE = re.compile(r"\d+")
_WORD_RE = re.compile(r"[a-z0-9']+")

# Negation detection: contractions ending in n't plus common words.
_NEGATION_RE = re.compile(
    r"\b\w*n't\b|\b(not|no|never|none|nothing|nobody|neither|nor|cannot|"
    r"without|refuse|deny|stop)\b",
    re.IGNORECASE,
)


def has_negation(text: str) -> bool:
    return _NEGATION_RE.search(text) is not None


def digit_sequences(text: str) -> set[str]:
    return set(_DIGITS_RE.findall(text))


def intent_preservation_score(original: str, rewrite: str) -> float:
    score = 1.0
    if utf16_length(rewrite) < 0.4 * utf16_length(original):
        score -= 0.25
    lost = digit_sequences(original) - digit_sequences(rewrite)
    score -= min(0.4, 0.2 * len(lost))
    return round(max(0.0, min(1.0, score)), 2)


def relevance(original: str, agenda: str) -> tuple[float, str]:
    """Returns (score, label). Advisory only — see module docstring."""
    agenda_words = set(_WORD_RE.findall(agenda.lower()))
    rewrite_words = set(_WORD_RE.findall(original.lower()))
    if not agenda_words:
        # An empty agenda carries no signal; do not guess off_topic.
        return 0.5, "borderline"
    overlap = len(agenda_words & rewrite_words) / len(agenda_words)
    if overlap >= 0.5:
        label = "relevant"
    elif overlap >= 0.15:
        label = "borderline"
    else:
        label = "off_topic"
    return round(min(1.0, overlap), 2), label
