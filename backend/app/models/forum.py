"""
AuraMind — Module 1: Zero-Knowledge Anonymous Community Forum
Author: Abdullah Al Hamim (22299096)

SQLAlchemy ORM models matching database/forum_schema.sql
"""
import uuid
from datetime import datetime

from sqlalchemy import (
    Column, String, Text, Boolean, ForeignKey, Numeric, DateTime, CheckConstraint
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.database import Base  # existing shared Base/engine setup


class ForumPseudonym(Base):
    __tablename__ = "forum_pseudonyms"

    pseudonym_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.user_id", ondelete="CASCADE"),
                      nullable=False, unique=True)
    display_name = Column(String(50), nullable=False, unique=True)
    avatar_seed = Column(String(50), nullable=False)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)

    posts = relationship("ForumPost", back_populates="pseudonym")


class ForumPost(Base):
    __tablename__ = "forum_posts"

    post_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    pseudonym_id = Column(UUID(as_uuid=True), ForeignKey("forum_pseudonyms.pseudonym_id", ondelete="CASCADE"),
                           nullable=False)
    parent_post_id = Column(UUID(as_uuid=True), ForeignKey("forum_posts.post_id", ondelete="CASCADE"),
                             nullable=True)
    title = Column(String(200), nullable=True)
    body = Column(Text, nullable=False)
    scrubbed_body = Column(Text, nullable=True)
    moderation_status = Column(String(20), nullable=False, default="pending")
    is_hidden = Column(Boolean, nullable=False, default=False)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at = Column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    pseudonym = relationship("ForumPseudonym", back_populates="posts")

    __table_args__ = (
        CheckConstraint(
            "moderation_status IN ('pending','approved','quarantined','removed')",
            name="ck_forum_posts_status"
        ),
    )


class ModerationQueueItem(Base):
    __tablename__ = "moderation_queue"

    queue_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    post_id = Column(UUID(as_uuid=True), ForeignKey("forum_posts.post_id", ondelete="CASCADE"), nullable=False)
    flag_type = Column(String(30), nullable=False)
    confidence = Column(Numeric(4, 3), nullable=False)
    model_version = Column(String(50), nullable=False)
    reviewed = Column(Boolean, nullable=False, default=False)
    reviewed_by = Column(UUID(as_uuid=True), ForeignKey("users.user_id"), nullable=True)
    review_decision = Column(String(20), nullable=True)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)
    reviewed_at = Column(DateTime(timezone=True), nullable=True)


class SafespaceReport(Base):
    __tablename__ = "safespace_reports"

    report_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    post_id = Column(UUID(as_uuid=True), ForeignKey("forum_posts.post_id", ondelete="CASCADE"), nullable=False)
    reporter_pseudonym_id = Column(UUID(as_uuid=True), ForeignKey("forum_pseudonyms.pseudonym_id"), nullable=False)
    reason = Column(String(30), nullable=False)
    details = Column(Text, nullable=True)
    status = Column(String(20), nullable=False, default="open")
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)
    resolved_at = Column(DateTime(timezone=True), nullable=True)
    resolved_by = Column(UUID(as_uuid=True), ForeignKey("users.user_id"), nullable=True)
