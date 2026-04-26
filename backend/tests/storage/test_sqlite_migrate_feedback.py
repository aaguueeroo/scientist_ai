"""SQLite startup migration: legacy ``feedback`` without ``review_envelope``."""

from __future__ import annotations

from pathlib import Path

import pytest
import sqlite3
from pydantic import SecretStr
from sqlalchemy import text

from app.config.settings import Settings
from app.storage import db as db_module


@pytest.mark.asyncio
async def test_create_all_migrates_legacy_feedback_adds_review_envelope(
    tmp_path: Path,
) -> None:
    """Older on-disk DBs have ``feedback`` without ``review_envelope``; migration ALTERs."""
    dbf = tmp_path / "legacy.sqlite3"
    con = sqlite3.connect(dbf)
    con.executescript(
        """
        CREATE TABLE feedback (
            feedback_id VARCHAR(64) NOT NULL,
            plan_id VARCHAR(64) NOT NULL,
            request_id VARCHAR(64) NOT NULL,
            schema_version INTEGER NOT NULL,
            prompt_versions JSON NOT NULL,
            domain_tag VARCHAR(64) NOT NULL,
            corrected_field VARCHAR(120) NOT NULL,
            before_text VARCHAR(4000) NOT NULL,
            after_text VARCHAR(4000) NOT NULL,
            reason VARCHAR(2000) NOT NULL,
            created_at DATETIME NOT NULL,
            PRIMARY KEY (feedback_id)
        );
        """
    )
    con.close()
    url = f"sqlite+aiosqlite:///{dbf.resolve().as_posix()}"
    settings = Settings(
        OPENAI_API_KEY=SecretStr("sk-test"),
        TAVILY_API_KEY=SecretStr("tvly-test"),
        DATABASE_URL=url,
    )
    engine = db_module.create_engine(settings)
    try:
        await db_module.create_all(engine)
        async with engine.connect() as db_conn:
            res = await db_conn.execute(text("PRAGMA table_info(feedback)"))
            names = {row[1] for row in res.fetchall()}
        assert "review_envelope" in names
    finally:
        await engine.dispose()
