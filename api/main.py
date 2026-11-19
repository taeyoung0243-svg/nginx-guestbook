"""방명록 API 서버 (FastAPI + SQLite).

Nginx가 /api/ 요청을 이 서버(127.0.0.1:8000)로 넘겨준다 (리버스 프록시).
"""
import os
import sqlite3
from contextlib import contextmanager
from datetime import datetime, timezone

from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel, Field

DB_PATH = os.environ.get("GUESTBOOK_DB", "guestbook.db")

app = FastAPI(title="Guestbook API", docs_url="/api/docs", openapi_url="/api/openapi.json")


@contextmanager
def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()


def init_db() -> None:
    with get_db() as db:
        db.execute(
            """
            CREATE TABLE IF NOT EXISTS messages (
                id         INTEGER PRIMARY KEY AUTOINCREMENT,
                name       TEXT    NOT NULL,
                content    TEXT    NOT NULL,
                created_at TEXT    NOT NULL
            )
            """
        )


init_db()


class MessageIn(BaseModel):
    name: str = Field(min_length=1, max_length=20)
    content: str = Field(min_length=1, max_length=200)


@app.get("/api/health")
def health():
    """서버 상태 확인용 (curl http://서버IP/api/health)."""
    return {"status": "ok", "hostname": os.uname().nodename}


@app.get("/api/messages")
def list_messages(limit: int = 50):
    limit = max(1, min(limit, 100))
    with get_db() as db:
        rows = db.execute(
            "SELECT id, name, content, created_at FROM messages ORDER BY id DESC LIMIT ?",
            (limit,),
        ).fetchall()
    return [dict(r) for r in rows]


@app.post("/api/messages", status_code=201)
def create_message(msg: MessageIn):
    name, content = msg.name.strip(), msg.content.strip()
    if not name or not content:
        raise HTTPException(status_code=422, detail="이름과 내용을 입력하세요.")
    created_at = datetime.now(timezone.utc).isoformat(timespec="seconds")
    with get_db() as db:
        cur = db.execute(
            "INSERT INTO messages (name, content, created_at) VALUES (?, ?, ?)",
            (name, content, created_at),
        )
    return {"id": cur.lastrowid, "name": name, "content": content, "created_at": created_at}


@app.get("/api/whoami")
def whoami(request: Request):
    """Nginx가 넘겨준 헤더를 보여준다 (리버스 프록시 동작 확인용)."""
    return {
        "client_ip": request.headers.get("x-real-ip", request.client.host if request.client else None),
        "forwarded_for": request.headers.get("x-forwarded-for"),
        "host": request.headers.get("host"),
    }
