"""
AuraMind — Module 1: Forum Pydantic schemas
Author: Abdullah Al Hamim (22299096)
"""
import uuid
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class PostCreate(BaseModel):
    title: Optional[str] = Field(None, max_length=200)
    body: str = Field(..., min_length=1, max_length=5000)
    parent_post_id: Optional[uuid.UUID] = None  # set when replying to another post


class PostOut(BaseModel):
    """What the client actually receives — never includes user_id."""
    post_id: uuid.UUID
    parent_post_id: Optional[uuid.UUID]
    title: Optional[str]
    body: str  # this is scrubbed_body (or body if no PII found)
    display_name: str
    avatar_seed: str
    created_at: datetime

    class Config:
        from_attributes = True


class ReportCreate(BaseModel):
    post_id: uuid.UUID
    reason: str = Field(..., pattern="^(harmful|triggering|harassment|spam|other)$")
    details: Optional[str] = Field(None, max_length=1000)


class ReportOut(BaseModel):
    report_id: uuid.UUID
    post_id: uuid.UUID
    status: str
    created_at: datetime

    class Config:
        from_attributes = True
