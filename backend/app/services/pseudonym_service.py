"""
AuraMind — Module 1: Pseudonym Service
Author: Abdullah Al Hamim (22299096)

Handles the ONE point of contact between a real user_id and their fixed,
persistent forum pseudonym. No other module should query
forum_pseudonyms directly.
"""
import random
import uuid

from sqlalchemy.orm import Session

from app.models.forum import ForumPseudonym

_ADJECTIVES = [
    "Quiet", "Gentle", "Calm", "Brave", "Hopeful", "Steady", "Warm",
    "Wandering", "Patient", "Curious", "Kind", "Resilient",
]
_NOUNS = [
    "Otter", "Willow", "Harbor", "Ember", "Meadow", "Sparrow", "River",
    "Lantern", "Maple", "Comet", "Fern", "Horizon",
]


def _generate_candidate_name() -> str:
    return f"{random.choice(_ADJECTIVES)}{random.choice(_NOUNS)}{random.randint(10, 999)}"


def get_or_create_pseudonym(db: Session, user_id: uuid.UUID) -> ForumPseudonym:
    """
    Returns the user's existing pseudonym, or creates one on first forum
    interaction. Pseudonyms are fixed for the lifetime of the account
    (see design decision in forum_schema.sql).
    """
    pseudonym = (
        db.query(ForumPseudonym)
        .filter(ForumPseudonym.user_id == user_id)
        .first()
    )
    if pseudonym:
        return pseudonym

    # Retry on the rare display_name collision.
    for _ in range(10):
        candidate = _generate_candidate_name()
        exists = (
            db.query(ForumPseudonym)
            .filter(ForumPseudonym.display_name == candidate)
            .first()
        )
        if not exists:
            pseudonym = ForumPseudonym(
                user_id=user_id,
                display_name=candidate,
                avatar_seed=candidate,  # Flutter side derives an icon/color from this seed
            )
            db.add(pseudonym)
            db.commit()
            db.refresh(pseudonym)
            return pseudonym

    raise RuntimeError("Failed to generate a unique pseudonym after 10 attempts")
