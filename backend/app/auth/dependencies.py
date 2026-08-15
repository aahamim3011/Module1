"""
DEMO-ONLY auth stub. The real project's auth module issues JWTs at
login and decodes them here. For this standalone test run, we simulate
a logged-in user via a simple header: `X-Demo-User-Id: <uuid>`.
"""
import uuid
from dataclasses import dataclass

from fastapi import Header, HTTPException


@dataclass
class CurrentUser:
    user_id: uuid.UUID


def get_current_user(x_demo_user_id: str = Header(...)) -> CurrentUser:
    try:
        return CurrentUser(user_id=uuid.UUID(x_demo_user_id))
    except ValueError:
        raise HTTPException(status_code=401, detail="Invalid demo user id")
