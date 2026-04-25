"""Async SQLAlchemy engine + session factory wired into FastAPI lifespan.

The engine is built once per process from `settings.DATABASE_URL`
(`sqlite+aiosqlite://...`). `create_all` runs `Base.metadata.create_all`
inside a connection: idempotent, safe to call on every startup
(`CREATE TABLE IF NOT EXISTS`). Tests construct an in-memory engine
(`sqlite+aiosqlite:///:memory:`) so the suite stays fully offline.
"""

from __future__ import annotations

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
    """Run `Base.metadata.create_all` (CREATE TABLE IF NOT EXISTS)."""

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
