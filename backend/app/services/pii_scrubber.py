"""
AuraMind — Module 1: PII Scrubbing Service
Author: Abdullah Al Hamim (22299096)

Strips personally identifiable information out of forum post text before
it is ever stored in `scrubbed_body` / served publicly. Two layers:

1. Regex layer (fast, deterministic) — catches emails, phone numbers,
   URLs, and common Bangladeshi/international phone formats.
2. Optional NER layer (spaCy) — catches PERSON / GPE (location) / ORG
   named entities that regex can't. Disabled by default so the service
   works even before `en_core_web_sm` is installed; flip
   ENABLE_NER_SCRUB to True once the model is available.

Usage:
    from app.services.pii_scrubber import scrub_text
    clean = scrub_text(raw_body)
"""
import re

ENABLE_NER_SCRUB = False  # set True after `python -m spacy download en_core_web_sm`

_EMAIL_RE = re.compile(r"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}")
_URL_RE = re.compile(r"(https?://\S+|www\.\S+)")
_PHONE_RE = re.compile(
    r"(?:\+?88)?01[3-9]\d{8}"          # Bangladeshi mobile numbers
    r"|\+?\d{1,3}[-.\s]?\(?\d{2,4}\)?[-.\s]?\d{3,4}[-.\s]?\d{3,4}"  # generic international
)
_HANDLE_RE = re.compile(r"@\w{2,30}")  # social handles someone might paste in

_REPLACEMENTS = [
    (_EMAIL_RE, "[email removed]"),
    (_URL_RE, "[link removed]"),
    (_PHONE_RE, "[phone number removed]"),
    (_HANDLE_RE, "[handle removed]"),
]

_nlp = None  # lazy-loaded spaCy pipeline


def _get_nlp():
    global _nlp
    if _nlp is None:
        import spacy
        _nlp = spacy.load("en_core_web_sm")
    return _nlp


def _scrub_named_entities(text: str) -> str:
    """Redacts PERSON, GPE (location), and ORG entities using spaCy NER."""
    nlp = _get_nlp()
    doc = nlp(text)
    out = text
    # Replace longest spans first so offsets don't shift on overlaps.
    for ent in sorted(doc.ents, key=lambda e: -len(e.text)):
        if ent.label_ in {"PERSON", "GPE", "ORG"}:
            out = out.replace(ent.text, f"[{ent.label_.lower()} removed]")
    return out


def scrub_text(raw_text: str) -> str:
    """
    Returns a PII-scrubbed copy of raw_text. This is the version stored in
    forum_posts.scrubbed_body and the ONLY version ever sent to clients.
    The original `body` is retained for audit/moderation purposes only —
    it must never be exposed via public_forum_feed.
    """
    if not raw_text:
        return raw_text

    cleaned = raw_text
    for pattern, replacement in _REPLACEMENTS:
        cleaned = pattern.sub(replacement, cleaned)

    if ENABLE_NER_SCRUB:
        cleaned = _scrub_named_entities(cleaned)

    return cleaned
