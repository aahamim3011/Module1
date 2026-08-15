"""
Minimal stand-in for the Auth module's User model — just enough for
SQLAlchemy to resolve the `users` foreign key used by forum models.
The real project's Auth module already defines this properly.
"""
import uuid
from sqlalchemy import Column, String, DateTime
from sqlalchemy.dialects.postgresql import UUID
from datetime import datetime

from app.database import Base


class User(Base):
    __tablename__ = "users"

    user_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(String(255), unique=True, nullable=False)
    username = Column(String(100), unique=True, nullable=False)
    phone_number = Column(String(20))
    password_hash = Column(String, nullable=False)
    role = Column(String(20), nullable=False, default="end_user")
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)
