"""Tests for `LiteratureReviewRepo::list_literature_reviews`."""

from __future__ import annotations

import asyncio
from collections.abc import AsyncIterator

import pytest
import pytest_asyncio
from pydantic import SecretStr
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.config.settings import Settings
from app.schemas.literature_qc import LiteratureQCResult, NoveltyLabel
from app.storage import db as db_module
from app.storage.literature_review_repo import LiteratureReviewRepo


def _settings() -> Settings:
    return Settings(
        OPENAI_API_KEY=SecretStr("sk-test"),
        TAVILY_API_KEY=SecretStr("tvly-test"),
        DATABASE_URL="sqlite+aiosqlite:///:memory:",
    )


@pytest_asyncio.fixture
async def session_factory() -> AsyncIterator[async_sessionmaker[AsyncSession]]:
    engine = db_module.create_engine(_settings())
    await db_module.create_all(engine)
    factory = db_module.async_session(engine)
    try:
        yield factory
    finally:
        await engine.dispose()


def _qc() -> LiteratureQCResult:
    return LiteratureQCResult(
        novelty=NoveltyLabel.NOT_FOUND,
        references=[],
        confidence="medium",
        tier_0_drops=0,
    )


@pytest.mark.asyncio
async def test_list_literature_reviews_returns_rows_newest_first(
    session_factory: async_sessionmaker[AsyncSession],
) -> None:
    repo = LiteratureReviewRepo(session_factory)
    await repo.save(
        literature_review_id="lr-older",
        request_id="r1",
        query="first query text",
        qc=_qc(),
    )
    await asyncio.sleep(0.02)
    await repo.save(
        literature_review_id="lr-newer",
        request_id="r2",
        query="second query text",
        qc=_qc(),
    )
    out = await repo.list_literature_reviews(limit=10)
    assert len(out) == 2
    assert out[0]["literature_review_id"] == "lr-newer"
    assert out[0]["query"] == "second query text"
    assert out[1]["literature_review_id"] == "lr-older"
    assert all("created_at" in x and "request_id" in x for x in out)
