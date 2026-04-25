"""Schema-evolution test for `PlansRepo` (Step 38).

Writes a row with `schema_version = 0` directly into the DB and asserts
the read path raises a clear `SchemaVersionMismatch`. Also confirms that
a row written through `save()` (which stamps `PLAN_SCHEMA_VERSION`)
loads back cleanly. Migration is deferred to v2 by design.
"""

from __future__ import annotations

from collections.abc import AsyncIterator
from datetime import UTC, datetime

import pytest
import pytest_asyncio
from pydantic import SecretStr
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.config.settings import Settings
from app.schemas.literature_qc import LiteratureQCResult, NoveltyLabel
from app.schemas.responses import GeneratePlanResponse
from app.storage import db as db_module
from app.storage.models import PLAN_SCHEMA_VERSION, PlanRow
from app.storage.plans_repo import PlansRepo, SchemaVersionMismatch


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


def _response(plan_id: str) -> GeneratePlanResponse:
    return GeneratePlanResponse(
        plan_id=plan_id,
        request_id="req-evolution",
        qc=_qc(),
        plan=None,
        grounding_summary=None,
        prompt_versions={"literature_qc.md": "abc"},
    )


@pytest.mark.asyncio
async def test_plans_repo_old_schema_row_raises_clear_schema_version_mismatch(
    session_factory: async_sessionmaker[AsyncSession],
) -> None:
    repo = PlansRepo(session_factory)

    response = _response("plan-old-001")
    async with session_factory() as session, session.begin():
        session.add(
            PlanRow(
                plan_id=response.plan_id,
                request_id=response.request_id,
                schema_version=0,
                prompt_versions=dict(response.prompt_versions),
                domain_tag=None,
                payload=response.model_dump(mode="json"),
                created_at=datetime.now(UTC).replace(tzinfo=None),
            )
        )

    with pytest.raises(SchemaVersionMismatch) as excinfo:
        await repo.get_by_id("plan-old-001")
    assert "schema_version" in str(excinfo.value).lower()


@pytest.mark.asyncio
async def test_plans_repo_current_schema_row_loads_cleanly(
    session_factory: async_sessionmaker[AsyncSession],
) -> None:
    repo = PlansRepo(session_factory)
    response = _response("plan-current-001")

    await repo.save(
        response=response,
        prompt_versions=response.prompt_versions,
        request_id=response.request_id,
    )

    loaded = await repo.get_by_id("plan-current-001")
    assert loaded is not None
    assert loaded.plan_id == "plan-current-001"

    row = await repo.get_row_by_id("plan-current-001")
    assert row is not None
    assert row.schema_version == PLAN_SCHEMA_VERSION
