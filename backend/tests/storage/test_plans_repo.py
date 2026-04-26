"""Tests for `app/storage/plans_repo.py::PlansRepo` (Step 36)."""

from __future__ import annotations

import re
from collections.abc import AsyncIterator

import pytest
import pytest_asyncio
from pydantic import SecretStr
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.config.settings import Settings
from app.schemas.literature_qc import LiteratureQCResult, NoveltyLabel
from app.schemas.responses import GeneratePlanResponse
from app.storage import db as db_module
from app.storage.models import PLAN_SCHEMA_VERSION
from app.storage.plans_repo import PlansRepo


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


def _qc(novelty: NoveltyLabel = NoveltyLabel.NOT_FOUND) -> LiteratureQCResult:
    return LiteratureQCResult(
        novelty=novelty,
        references=[],
        confidence="medium",
        tier_0_drops=0,
    )


def _response(
    *,
    plan_id: str = "plan-test-001",
    request_id: str = "req-test-001",
) -> GeneratePlanResponse:
    return GeneratePlanResponse(
        plan_id=plan_id,
        request_id=request_id,
        qc=_qc(),
        plan=None,
        grounding_summary=None,
        prompt_versions={
            "literature_qc.md": "abc",
            "feedback_relevance.md": "def",
            "experiment_planner.md": "ghi",
        },
    )


@pytest.mark.asyncio
async def test_plans_repo_save_and_get_round_trips(
    session_factory: async_sessionmaker[AsyncSession],
) -> None:
    repo = PlansRepo(session_factory)
    response = _response()

    await repo.save(
        response=response,
        prompt_versions=response.prompt_versions,
        request_id=response.request_id,
    )

    loaded = await repo.get_by_id("plan-test-001")
    assert loaded is not None
    assert loaded.plan_id == "plan-test-001"
    assert loaded.qc["novelty"] == NoveltyLabel.NOT_FOUND.value


@pytest.mark.asyncio
async def test_plans_repo_save_persists_prompt_versions_and_schema_version(
    session_factory: async_sessionmaker[AsyncSession],
) -> None:
    repo = PlansRepo(session_factory)
    response = _response(plan_id="plan-test-002")

    await repo.save(
        response=response,
        prompt_versions=response.prompt_versions,
        request_id=response.request_id,
    )

    row = await repo.get_row_by_id("plan-test-002")
    assert row is not None
    assert row.schema_version == PLAN_SCHEMA_VERSION
    assert row.prompt_versions == response.prompt_versions


@pytest.mark.asyncio
async def test_plans_repo_save_persists_request_id_matching_log_line(
    session_factory: async_sessionmaker[AsyncSession],
) -> None:
    repo = PlansRepo(session_factory)
    response = _response(plan_id="plan-test-003", request_id="req-log-xyz")

    await repo.save(
        response=response,
        prompt_versions=response.prompt_versions,
        request_id=response.request_id,
    )

    row = await repo.get_row_by_id("plan-test-003")
    assert row is not None
    assert row.request_id == "req-log-xyz"


@pytest.mark.asyncio
async def test_plans_repo_get_by_id_returns_none_for_unknown_id(
    session_factory: async_sessionmaker[AsyncSession],
) -> None:
    repo = PlansRepo(session_factory)
    assert await repo.get_by_id("plan-unknown") is None
    assert await repo.get_row_by_id("plan-unknown") is None


@pytest.mark.asyncio
async def test_plans_repo_delete_by_plan_id_removes_row(
    session_factory: async_sessionmaker[AsyncSession],
) -> None:
    repo = PlansRepo(session_factory)
    response = _response(plan_id="plan-delete-me")
    await repo.save(
        response=response,
        prompt_versions=response.prompt_versions,
        request_id=response.request_id,
    )
    assert await repo.get_row_by_id("plan-delete-me") is not None

    removed = await repo.delete_by_plan_id("plan-delete-me")
    assert removed is True
    assert await repo.get_row_by_id("plan-delete-me") is None

    again = await repo.delete_by_plan_id("plan-delete-me")
    assert again is False


@pytest.mark.asyncio
async def test_allocate_unique_plan_id_format_and_uniqueness(
    session_factory: async_sessionmaker[AsyncSession],
) -> None:
    repo = PlansRepo(session_factory)
    ids = {await repo.allocate_unique_plan_id() for _ in range(12)}
    assert len(ids) == 12
    for pid in ids:
        assert re.fullmatch(r"[A-Za-z0-9]{24}", pid)


@pytest.mark.asyncio
async def test_allocate_unique_plan_id_skips_taken_id(
    session_factory: async_sessionmaker[AsyncSession],
) -> None:
    taken = "a" * 24
    repo = PlansRepo(session_factory)
    response = _response(plan_id=taken)
    await repo.save(
        response=response,
        prompt_versions=response.prompt_versions,
        request_id=response.request_id,
    )

    from unittest import mock

    with mock.patch(
        "app.storage.plans_repo.secrets.choice",
        side_effect=(["a"] * 24) + (["b"] * 24),
    ):
        got = await repo.allocate_unique_plan_id()

    assert got == "b" * 24
