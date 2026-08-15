from fastapi import FastAPI
from app.models import user  # noqa: F401 — registers `users` table for FK resolution
from app.routers import forum

app = FastAPI(title="AuraMind — Module 1 Demo (Forum)")
app.include_router(forum.router)


@app.get("/")
def root():
    return {"status": "ok", "module": "Zero-Knowledge Anonymous Community Forum"}
