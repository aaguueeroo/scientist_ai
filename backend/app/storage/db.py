"""Async SQLAlchemy engine + session factory wired into FastAPI lifespan.

The engine is built once per process from `settings.DATABASE_URL`
(`sqlite+aiosqlite://...`). `create_all` runs `Base.metadata.create_all`
inside a connection: idempotent, safe to call on every startup
(`CREATE TABLE IF NOT EXISTS`). Tests construct an in-memory engine
(`sqlite+aiosqlite:///:memory:`) so the suite stays fully offline.
"""

from __future__ import annotations

from typing import Any

from sqlalchemy import inspect, text
from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from app.config.settings import Settings
from app.storage.models import Base


def create_engine(settings: Settings) -> AsyncEngine:
    """Build a fresh `AsyncEngine` from settings."""

    return create_async_engine(
        settings.DATABASE_URL,
        future=True,
        pool_pre_ping=True,
    )


def async_session(engine: AsyncEngine) -> async_sessionmaker[AsyncSession]:
    """Return an `async_sessionmaker` bound to `engine`.

    Caller code (repos, route handlers) opens a per-request session via
    the returned factory: ``async with session_factory() as session: ...``.
    """

    return async_sessionmaker(
        engine,
        expire_on_commit=False,
        class_=AsyncSession,
    )


async def create_all(engine: AsyncEngine) -> None:
    """Run `Base.metadata.create_all` (CREATE TABLE IF NOT EXISTS).

    On SQLite, also runs additive :func:`migrate_sqlite_schema` so on-disk
    DBs from before a new column (e.g. ``review_envelope``) still work.
    """

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    await migrate_sqlite_schema(engine)


def _sqlite_add_feedback_review_envelope(connection: Any) -> None:
    """`create_all` does not ALTER; add column for DBs from before A1 plan-review."""
    insp = inspect(connection)
    if "feedback" not in insp.get_table_names():
        return
    col_names = {c["name"] for c in insp.get_columns("feedback")}
    if "review_envelope" in col_names:
        return
    connection.execute(
        text("ALTER TABLE feedback ADD COLUMN review_envelope JSON")
    )


async def migrate_sqlite_schema(engine: AsyncEngine) -> None:
    """Apply additive SQLite migrations for on-disk DBs (no Alembic in dev).

    Call after :func:`create_all`. Non-SQLite engines are skipped.
    """

    if "sqlite" not in str(engine.url).lower():
        return
    async with engine.begin() as conn:
        await conn.run_sync(_sqlite_add_feedback_review_envelope)
