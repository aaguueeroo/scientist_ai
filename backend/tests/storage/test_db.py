"""Tests for the async-SQLAlchemy/aiosqlite engine + session helpers (Step 35)."""

from __future__ import annotations

import pytest
from pydantic import SecretStr
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncEngine

from app.api import deps as api_deps
from app.config.settings import Settings
from app.storage import db as db_module


def _in_memory_settings() -> Settings:
    return Settings(
        OPENAI_API_KEY=SecretStr("sk-test"),
        TAVILY_API_KEY=SecretStr("tvly-test"),
        DATABASE_URL="sqlite+aiosqlite:///:memory:",
    )


@pytest.mark.asyncio
async def test_db_engine_creates_in_memory_sqlite_for_tests() -> None:
    settings = _in_memory_settings()
    engine = db_module.create_engine(settings)
    try:
        assert isinstance(engine, AsyncEngine)
        assert "sqlite+aiosqlite" in str(engine.url)
        async with engine.connect() as conn:
            result = await conn.execute(text("SELECT 1"))
            row = result.fetchone()
            assert row is not None
            assert row[0] == 1
    finally:
        await engine.dispose()


@pytest.mark.asyncio
async def test_db_metadata_create_all_is_idempotent() -> None:
    settings = _in_memory_settings()
    engine = db_module.create_engine(settings)
    try:
        await db_module.create_all(engine)
        await db_module.create_all(engine)
    finally:
        await engine.dispose()


@pytest.mark.asyncio
async def test_lifespan_disposes_engine_on_shutdown(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from app.main import create_app

    dispose_calls = {"count": 0}
    real_create = db_module.create_engine
    original_dispose = AsyncEngine.dispose

    async def _spy_dispose(self: AsyncEngine, close: bool = True) -> None:
        dispose_calls["count"] += 1
        await original_dispose(self, close=close)

    monkeypatch.setattr(AsyncEngine, "dispose", _spy_dispose)
    monkeypatch.setattr(
        db_module,
        "create_engine",
        lambda settings: real_create(_in_memory_settings()),
    )

    app = create_app()
    async with app.router.lifespan_context(app):
        engine = app.state.db_engine
        assert isinstance(engine, AsyncEngine)
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))

    assert dispose_calls["count"] >= 1

    _ = api_deps  # parity with production wiring
