"""English-only gate (decided product policy).

A dependency-free heuristic, not a language identifier. Two layers:

1. Script check — text that is meaningfully non-Latin (Cyrillic, CJK,
   Arabic, ...) is refused outright.
2. Vocabulary check — Latin-script text passes when a clear majority
   signal of English vocabulary is present: at least one third of its
   words are recognized English words (function words like the, is,
   please, or common content words like meeting, deadline, tomorrow).
   Multi-word Latin text with almost no English vocabulary signal
   ("hola como estas te veo", "quiero saber cuando vamos a empezar") is
   refused.

Policy for short or ambiguous input, documented for operators:

- Blank or whitespace-only input passes with no signal; the worker's
  output validation and the backend's own non-empty requirement handle
  blanks — this gate decides language, not emptiness.
- Input with fewer than three words cannot be classified reliably
  ("ok", "hola"), so it is given the benefit of the doubt. A single
  foreign word may therefore slip through; the gate's job is to refuse
  clearly unsupported languages, and the model plus the controller
  review handle quality beyond that. This trade-off is deliberate.

The vocabulary is a fixed, reviewed list — favoring unambiguous English
words — so behavior is deterministic and testable. The one-third
coverage bar keeps mixed messages working (a name, a URL, or one
foreign word inside an English sentence still passes) while refusing
text that is essentially foreign despite sharing stray short words
like "a" or "me". Text is never logged here or anywhere else in the
failure path.
"""

from __future__ import annotations

import re

# Ranges for scripts an English-only pipeline must refuse. Latin and
# Latin-1/Extended letters (é, ñ, ü ...) are treated as Latin.
_NON_LATIN_RANGES: tuple[tuple[int, int], ...] = (
    (0x0370, 0x03FF),  # Greek
    (0x0400, 0x04FF),  # Cyrillic
    (0x0590, 0x05FF),  # Hebrew
    (0x0600, 0x06FF),  # Arabic
    (0x0900, 0x097F),  # Devanagari
    (0x0E00, 0x0E7F),  # Thai
    (0x3040, 0x30FF),  # Hiragana + Katakana
    (0x3400, 0x4DBF),  # CJK extension A
    (0x4E00, 0x9FFF),  # CJK unified
    (0xAC00, 0xD7AF),  # Hangul
)

_WORD_RE = re.compile(r"[a-zA-Z']+")

# Function words: the small closed class that almost every English
# sentence contains at least one of.
_FUNCTION_WORDS = frozenset(
    """the a an and or but if then else of to in on at for with from by as
    is are was were be been being am do does did done have has had i you
    he she it we they me him her us them my your his its our their this
    that these those not no never please can could will would should may
    might must about into over under out up down so just very really
    what when where why how who whom which""".split()
)

# Common content words seen in student/workplace messages. Curated to
# unambiguous English spellings; the any-match rule means one hit is
# enough, so recall matters more than coverage.
_CONTENT_WORDS = frozenset(
    """hi hello hey thanks thank sorry welcome ok okay sure yes yeah yep
    nope regards sincerely maybe perhaps probably definitely
    today tomorrow yesterday now soon later tonight morning afternoon
    evening night week weeks month months year years day days hour hours
    minute minutes monday tuesday wednesday thursday friday saturday
    sunday january february march april june july august september
    october november december weekend deadline due early late before
    after already still always often sometimes asap
    start starts starting started end ends ending ended finish finishes
    finished complete completed submit submits submitting submitted send
    sends sending sent review reviews reviewing reviewed check checks
    checking checked share shares sharing shared attend attends attending
    attended join joins joining joined meet meets meeting meetings call
    calls calling called talk talks talking discussed discuss discussing
    work works working worked need needs needing needed want wants
    wanting wanted try tries trying tried help helps helping helped make
    makes making made get gets getting got give gives giving gave take
    takes taking took see sees seeing saw look looks looking looked
    think thinks thinking thought know knows knowing knew say says saying
    said tell tells telling told ask asks asking asked answer answers
    answering answered reply replies replying replied read reads reading
    write writes writing wrote written update updates updating updated
    fix fixes fixing fixed change changes changing changed add adds
    adding added remove removes removing removed delete deletes deleting
    deleted create creates creating created build builds building built
    run runs running ran test tests testing tested let
    notes note report reports document documents docs doc file files
    folder link links page pages slide slides presentation project
    projects task tasks assignment assignments exam exams quiz quizzes
    homework class classes lecture lectures lab labs session sessions
    schedule agenda topic topics question questions doubt doubts issue
    issues problem problems error errors bug bugs feedback approval
    approve approved reject rejected message messages chat group groups
    team teams member members controller contributor post posts comment
    comments email emails mail attachment attachments resume interview
    interviews time times date dates place venue room office home zoom
    drive github repo repository branch code summary summaries draft
    drafts version versions submission
    good great fine bad better best ready done pending important urgent
    quick quickly fast slow new old first second last next final small
    big large short long free busy available unavailable possible
    impossible""".split()
)

_ENGLISH_VOCABULARY = _FUNCTION_WORDS | _CONTENT_WORDS


def _is_non_latin(ch: str) -> bool:
    code = ord(ch)
    return any(lo <= code <= hi for lo, hi in _NON_LATIN_RANGES)


def looks_like_english(text: str) -> bool:
    """True when the text passes the English-only gate.

    Empty/whitespace input returns True (no signal): blankness is the
    caller's concern, and the caller's blank checks produce the right
    error codes.
    """
    letters = [ch for ch in text if ch.isalpha()]
    if not letters:
        # Digits, emoji, punctuation only: no language signal either way.
        return True
    non_latin = sum(1 for ch in letters if _is_non_latin(ch))
    if non_latin / len(letters) > 0.2:
        return False

    words = _WORD_RE.findall(text.lower())
    if not words:
        return True
    recognized = sum(1 for word in words if word in _ENGLISH_VOCABULARY)
    # One-third coverage: ordinary English clears it easily; foreign
    # sentences that merely share a stray short word ("a", "me") do not.
    if recognized / len(words) >= 0.34:
        return True
    # Latin text too short to classify reliably ("ok", "hola"): benefit
    # of the doubt, per the documented policy. Multi-word Latin text
    # with almost no vocabulary signal ("hola como estas te veo") is not
    # provably English, and this pipeline is English-only.
    return len(words) < 3
