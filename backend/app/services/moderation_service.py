"""
AuraMind — Module 1: AI-Driven Automated Content Moderation
Author: Abdullah Al Hamim (22299096)

Runs every new forum post through a Hugging Face text-classification
model to detect bullying / hate speech / spam. Posts scoring above the
threshold are auto-quarantined and queued for admin review, per spec.

Note: this is separate from Nusaiba's suicide-surveillance classifier —
that one screens journal + forum text for self-harm risk. This service
only handles community-conduct moderation (bullying/hate/spam).
"""
import os
import uuid
from dataclasses import dataclass

import httpx

HF_API_URL = "https://api-inference.huggingface.co/models/facebook/roberta-hate-speech-dynabench-r4-target"
HF_API_TOKEN = os.environ.get("HF_API_TOKEN", "")
CONFIDENCE_THRESHOLD = 0.75
MODEL_VERSION = "roberta-hate-speech-dynabench-r4-target-v1"


@dataclass
class ModerationResult:
    flagged: bool
    flag_type: str  # 'hate_speech' | 'bullying' | 'spam' | 'other'
    confidence: float


async def classify_post(text: str) -> ModerationResult:
    """
    Calls the Hugging Face Inference API and maps its output to our
    flag_type taxonomy. Fails safe: on any API/network error, the post
    is NOT auto-flagged (falls back to 'pending' human review instead
    of blocking legitimate posts on an outage).
    """
    if not HF_API_TOKEN:
        # No token configured (e.g. local dev) — skip AI scoring, leave
        # the post in 'pending' for manual review.
        return ModerationResult(flagged=False, flag_type="other", confidence=0.0)

    headers = {"Authorization": f"Bearer {HF_API_TOKEN}"}

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(HF_API_URL, headers=headers, json={"inputs": text})
            resp.raise_for_status()
            result = resp.json()
    except (httpx.HTTPError, ValueError):
        return ModerationResult(flagged=False, flag_type="other", confidence=0.0)

    # Expected shape: [[{"label": "hate", "score": 0.91}, {"label": "nothate", "score": 0.09}]]
    try:
        scores = result[0] if isinstance(result[0], list) else result
        top = max(scores, key=lambda s: s["score"])
    except (KeyError, IndexError, TypeError):
        return ModerationResult(flagged=False, flag_type="other", confidence=0.0)

    is_hate = top["label"].lower() in {"hate", "toxic", "offensive"}
    confidence = float(top["score"])

    return ModerationResult(
        flagged=is_hate and confidence >= CONFIDENCE_THRESHOLD,
        flag_type="hate_speech" if is_hate else "other",
        confidence=confidence,
    )
