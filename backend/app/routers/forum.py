"""
AuraMind — Module 1: Zero-Knowledge Anonymous Community Forum
Author: Abdullah Al Hamim (22299096)

Endpoints:
    POST /forum/posts          -> create a post or reply
    GET  /forum/posts          -> paginated public feed (approved, not hidden)
    POST /forum/reports        -> SafeSpace report (auto-hides the post)

Auth: every route requires a logged-in user (get_current_user), but the
response NEVER includes user_id — only the caller's own pseudonym is
resolved server-side and attached to what they create.
"""
import uuid
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.auth.dependencies import get_current_user  # existing auth module
from app.models.forum import ForumPost, ModerationQueueItem, SafespaceReport
from app.schemas.forum import PostCreate, PostOut, ReportCreate, ReportOut
from app.services.pii_scrubber import scrub_text
from app.services.pseudonym_service import get_or_create_pseudonym
from app.services.moderation_service import classify_post

router = APIRouter(prefix="/forum", tags=["forum"])


@router.post("/posts", response_model=PostOut, status_code=status.HTTP_201_CREATED)
async def create_post(
    payload: PostCreate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    pseudonym = get_or_create_pseudonym(db, current_user.user_id)

    if payload.parent_post_id:
        parent = db.query(ForumPost).filter(ForumPost.post_id == payload.parent_post_id).first()
        if not parent:
            raise HTTPException(status_code=404, detail="Parent post not found")

    cleaned_body = scrub_text(payload.body)

    post = ForumPost(
        pseudonym_id=pseudonym.pseudonym_id,
        parent_post_id=payload.parent_post_id,
        title=payload.title,
        body=payload.body,           # raw text, retained for moderation/audit only
        scrubbed_body=cleaned_body,  # what actually gets served publicly
        moderation_status="pending",
    )
    db.add(post)
    db.commit()
    db.refresh(post)

    # AI content moderation pass — bullying / hate speech / spam
    result = await classify_post(cleaned_body)
    if result.flagged:
        post.moderation_status = "quarantined"
        db.add(ModerationQueueItem(
            post_id=post.post_id,
            flag_type=result.flag_type,
            confidence=result.confidence,
            model_version="roberta-hate-speech-dynabench-r4-target-v1",
        ))
    else:
        post.moderation_status = "approved"
    db.commit()
    db.refresh(post)

    return PostOut(
        post_id=post.post_id,
        parent_post_id=post.parent_post_id,
        title=post.title,
        body=post.scrubbed_body,
        display_name=pseudonym.display_name,
        avatar_seed=pseudonym.avatar_seed,
        created_at=post.created_at,
    )


@router.get("/posts", response_model=List[PostOut])
def get_feed(
    skip: int = 0,
    limit: int = 20,
    db: Session = Depends(get_db),
):
    """Public feed — reads from the same access rules as public_forum_feed view."""
    posts = (
        db.query(ForumPost)
        .filter(ForumPost.moderation_status == "approved", ForumPost.is_hidden.is_(False))
        .order_by(ForumPost.created_at.desc())
        .offset(skip)
        .limit(min(limit, 50))
        .all()
    )
    return [
        PostOut(
            post_id=p.post_id,
            parent_post_id=p.parent_post_id,
            title=p.title,
            body=p.scrubbed_body or p.body,
            display_name=p.pseudonym.display_name,
            avatar_seed=p.pseudonym.avatar_seed,
            created_at=p.created_at,
        )
        for p in posts
    ]


@router.post("/reports", response_model=ReportOut, status_code=status.HTTP_201_CREATED)
def report_post(
    payload: ReportCreate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    post = db.query(ForumPost).filter(ForumPost.post_id == payload.post_id).first()
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")

    reporter_pseudonym = get_or_create_pseudonym(db, current_user.user_id)

    report = SafespaceReport(
        post_id=payload.post_id,
        reporter_pseudonym_id=reporter_pseudonym.pseudonym_id,
        reason=payload.reason,
        details=payload.details,
    )
    db.add(report)
    db.commit()
    db.refresh(report)

    # Note: the actual is_hidden=True flip happens via the DB trigger
    # (trg_hide_post_on_report) so it's atomic with the INSERT and can't
    # be skipped by forgetting to call it here.

    return report
