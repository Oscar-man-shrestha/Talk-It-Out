"""Deterministic moderation signals for submitted messages and rewrites.

Two jobs, both advisory and code-only (never message text in results,
logs or errors):

1. ``detect(text)`` labels the ORIGINAL message so the controller sees why
   it needed care: ``abusive_language`` (insults aimed at people),
   ``profanity``, ``hate_speech`` (attacks on a group or identity),
   ``threat`` and ``self_harm``. Flags never reject or hide a message: the
   controller decides (pipeline/AGENTS.md, relevance and flags are advisory).
2. ``offensive_left(rewrite)`` checks that a REWRITE no longer carries
   insults, profanity, hate or threats, so a tone rewrite that kept the
   abuse is caught and corrected (one retry) instead of being published.

Matching is tolerant of common disguises: letters repeated ("fuuuck"),
separators ("f.u.c.k") and digit/symbol swaps ("1d10t", "$hit"). Criticism
of THINGS is not abuse: "the dashboard is useless" is a legitimate
complaint and must survive the rewrite, so words like "useless" are not
listed. This is a heuristic first layer, not a classifier; the prompt and
the controller remain the main safeguards.
"""

from __future__ import annotations

import re

ABUSIVE = "abusive_language"
PROFANITY = "profanity"
HATE = "hate_speech"
THREAT = "threat"
SELF_HARM = "self_harm"

#: Stable order for reporting.
ALL_FLAGS = (HATE, THREAT, ABUSIVE, PROFANITY, SELF_HARM)

_LEET = str.maketrans({"0": "o", "1": "i", "3": "e", "4": "a", "5": "s",
                       "7": "t", "@": "a", "$": "s"})


def _normalize(text: str) -> str:
    # "!" stands for "i" only inside a word ("sh!t"), not at its end ("idiots!!").
    return re.sub(r"(?<=[a-z])!(?=[a-z])", "i", text.lower().translate(_LEET))


def _word_pattern(word: str) -> str:
    """'idiot' -> i+[\\W_]*d+[\\W_]*i+... : repeated letters and separators."""
    return r"[\W_]*".join(f"{re.escape(ch)}+" for ch in word)


def _lexicon(words: list[str]) -> re.Pattern[str]:
    alternatives = "|".join(_word_pattern(w) for w in sorted(words, key=len, reverse=True))
    return re.compile(rf"(?<![a-z])(?:{alternatives})(?:s|es|ed|ing|er|ers|y)?(?![a-z])")


_PROFANITY_RE = _lexicon([
    "fuck", "motherfucker", "shit", "bullshit", "bitch", "bastard", "asshole",
    "arsehole", "dickhead", "piss", "crap", "wtf", "stfu", "bloody hell",
    "bsdk", "chutiya", "madarchod", "behenchod", "gandu",
])

_INSULT_RE = _lexicon([
    "idiot", "moron", "stupid", "dumb", "dumbass", "imbecile", "retard",
    "loser", "clown", "jerk", "scum", "scumbag", "fool", "nincompoop",
    "pig", "donkey", "ullu", "bewakoof", "pagal",
])

_PEOPLE = (r"(you|you guys|you all|u|ur|your team|this team|the team|management|"
           r"he|she|they|him|her|them|everyone|everybody|people here|hr|"
           r"the manager|my manager|the lead|our lead)")

# An insult counts as abuse when it is aimed at people ("you idiots",
# "the team are clowns"), or appears as a bare name-calling word.
_AIMED_INSULT_RE = re.compile(
    rf"\b{_PEOPLE}\b[^.!?\n]{{0,25}}?\b(are|is|r|=)?\s*(a|an|such|total|complete|bunch of)?\s*"
    rf"(idiots?|morons?|stupid|dumb|losers?|clowns?|jerks?|scum|fools?|imbeciles?|"
    rf"pigs?|donkeys?|useless\s+people|incompetent\s+people|trash)\b"
)

_GROUPS = (r"(women|woman|men|girls|girl|boys|muslims|muslim|hindus|hindu|christians|jews|sikhs|buddhists|"
           r"blacks|whites|asians|africans|gays|lesbians|trans people|transgender people|"
           r"immigrants|foreigners|migrants|biharis|south indians|north indians|"
           r"northeasterners|dalits|brahmins|old people|freshers|disabled people)")

_HATE_RES = [
    # "all <group> are lazy", "those immigrants are criminals"
    re.compile(
        rf"\b(all|those|these|typical|most|every)\s+{_GROUPS}\b[^.!?\n]{{0,40}}?\b(are|r|is)\s+"
        r"(stupid|lazy|useless|dirty|criminals?|animals?|idiots?|thieves|terrorists?|"
        r"inferior|worthless|trash|disgusting|subhuman|vermin|parasites?|filth)\b"
    ),
    re.compile(rf"\b{_GROUPS}\b[^.!?\n]{{0,20}}?\b(should|must|need to)\s+"
               r"(die|be killed|be removed|go back|be banned|disappear)\b"),
    re.compile(r"\bgo back to (your|their) (own )?(country|village|state)\b"),
    # Denying a group's ability: "women can't do backend work".
    re.compile(rf"\b{_GROUPS}\s+(can('|no)?t|cannot|can not|shouldn'?t|should not|"
               r"don'?t|do not|never|are not able to|aren'?t able to)\s+"
               r"(do|be|handle|code|lead|work|understand|manage|think|drive|learn|build|program|perform|take|hold|run|write|teach|solve|make|deliver|grasp|cope)\b"),
    # Softened versions: "women may not be suited for backend work".
    re.compile(rf"\b{_GROUPS}\s+(may|might|could|would|do|does|are|is|r)?\s*(not|never|less|rarely)\s+"
               r"(be\s+)?(suited|suitable|fit|cut out|qualified|good at|good enough|able|right)\b"),
    re.compile(rf"\b{_GROUPS}\s+(are|r|is)\s+(not|never|less)\s+"
               r"(capable|smart|intelligent|good enough|fit|competent|logical|technical)\b"),
    re.compile(rf"\b{_GROUPS}\s+(are|r)\s+(animals|vermin|cockroaches|rats|parasites|subhuman)\b"),
]

_THREAT_RES = [
    re.compile(r"\b(i('| wi)ll|i am going to|i'm going to|im going to|gonna|i will)\s+"
               r"(kill|hurt|beat|stab|shoot|smash|break|slap|punch|attack|destroy|end)\s+"
               r"(you|u|him|her|them|your|his|their|everyone)\b"),
    re.compile(r"\b(kill|shoot|stab|beat up|slap|punch)\s+(you|u|him|her|them|everyone)\b"),
    re.compile(r"\byou\s+(should|deserve to|better|will)\s+(die|be killed|be hurt)\b"),
    re.compile(r"\b(kys|watch your back|you('| a)re dead|i know where you live)\b"),
]

_SELF_HARM_RE = re.compile(
    r"\b(kill myself|end my life|ending my life|suicid\w*|want to die|wanna die|"
    r"self[- ]harm|hurt myself|no reason to live)\b"
)

_REFUSAL_RE = re.compile(
    r"(\b(i\s+)?(can('|no)?t|cannot|am unable to|'m unable to|am not able to|won'?t)\s+"
    r"(help|assist|rewrite|rephrase|comply|fulfil+|provide|process)\b"
    r"(\s+(you\s+)?with\s+(that|this|the request|your request))?"
    r"|\bas an ai\b|\bi('m| am) (just )?a language model\b)",
    re.IGNORECASE,
)


def detect(text: str) -> list[str]:
    """Advisory flags for an original message, in a stable order."""
    t = _normalize(text)
    found: set[str] = set()
    if any(r.search(t) for r in _HATE_RES):
        found.add(HATE)
    if any(r.search(t) for r in _THREAT_RES):
        found.add(THREAT)
    if _AIMED_INSULT_RE.search(t) or _INSULT_RE.search(t):
        found.add(ABUSIVE)
    if _PROFANITY_RE.search(t):
        found.add(PROFANITY)
    if _SELF_HARM_RE.search(t):
        found.add(SELF_HARM)
    return [f for f in ALL_FLAGS if f in found]


_FILLER = frozenset("""
you u ur your yours guys all are is am be total totally complete completely
absolute absolutely such so very really bunch lot lots what the this that
these those they them him her she he and or but just lol lmao omg ugh hey
yeah yes well damn bloody fucking freaking hell man bro dude yaar re
""".split())


def has_substance(text: str) -> bool:
    """False when a message is nothing but abuse ("you idiots", "fuck this").

    Insults, swearing and filler removed, at least one real word must
    remain; otherwise there is nothing to rephrase, and a model would only
    invent content.
    """
    t = _normalize(text)
    # Masked swearing ("f***ing", "s**t") is still swearing.
    t = re.sub(r"[a-z]*\*+[a-z]*", " ", t)
    t = _PROFANITY_RE.sub(" ", t)
    t = _INSULT_RE.sub(" ", t)
    words = [w for w in re.findall(r"[a-z]{3,}", t) if w not in _FILLER]
    return bool(words)


_GROUP_WORD_RE = re.compile(rf"\b{_GROUPS}\b")

_PAIRS = {"women": "woman", "men": "man", "girls": "girl", "boys": "boy"}


def targeted_groups(text: str) -> set[str]:
    """Groups a hateful statement in [text] is about ("women", "dalits").

    Only groups named inside a hate match count, so a group mentioned
    neutrally elsewhere in the message is not included.
    """
    t = _normalize(text)
    groups: set[str] = set()
    for pattern in _HATE_RES:
        for match in pattern.finditer(t):
            for g in _GROUP_WORD_RE.finditer(match.group(0)):
                word = g.group(0)
                groups.add(word)
                groups.add(_PAIRS.get(word, word))
                groups.update(k for k, v in _PAIRS.items() if v == word)
                groups.add(word[:-1] if word.endswith("s") else word + "s")
    return groups


def mentions_any(text: str, groups: set[str]) -> bool:
    if not groups:
        return False
    t = _normalize(text)
    return any(re.search(rf"\b{re.escape(g)}\b", t) for g in groups)


def offensive_left(rewrite: str) -> bool:
    """True if a rewrite still carries abuse, profanity, hate or a threat.

    Self-harm wording is not "offensive": a calm rewrite may rightly keep
    that someone is struggling, so it is not checked here.
    """
    flags = set(detect(rewrite))
    return bool(flags & {HATE, THREAT, ABUSIVE, PROFANITY})


def is_refusal(output: str, original: str = "") -> bool:
    """The model declined instead of rewriting ("I can't help with that").

    An ordinary apology is not a refusal ("Sorry, I can't join the call"),
    and wording the sender used themselves never counts.
    """
    found = _REFUSAL_RE.search(output.strip())
    if found is None:
        return False
    return _REFUSAL_RE.search(original) is None
