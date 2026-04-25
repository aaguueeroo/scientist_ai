"""Tests for `app/storage/feedback_repo.py::FeedbackRepo` (Step 40)."""

from __future__ import annotations

import asyncio
from collections.abc import AsyncIterator

import pytest
import pytest_asyncio
from pydantic import SecretStr
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.config.settings import Settings
from app.schemas.feedback import DomainTag, FeedbackRecord
from app.storage import db as db_module
from app.storage.feedback_repo import FeedbackRepo
from app.storage.models import FEEDBACK_SCHEMA_VERSION


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


def _record(
    *,
    feedback_id: str,
    plan_id: str = "plan-feedback-001",
    domain_tag: DomainTag = DomainTag.CELL_BIOLOGY_CRYOPRESERVATION,
    corrected_field: str = "materials[0].vendor",
    before: str = "Acme",
    after: str = "Sigma-Aldrich",
    reason: str = "standard supplier per published protocol",
) -> FeedbackRecord:
    return FeedbackRecord(
        feedback_id=feedback_id,
        plan_id=plan_id,
        domain_tag=domain_tag,
        corrected_field=corrected_field,
        before=before,
        after=after,
        reason=reason,
    )


_PROMPT_VERSIONS: dict[str, str] = {
    "literature_qc.md": "qc",
    "feedback_relevance.md": "fb",
    "experiment_planner.md": "ep",
}


@pytest.mark.asyncio
async def test_feedback_repo_save_and_find_relevant_round_trips(
    session_factory: async_sessionmaker[AsyncSession],
) -> None:
    repo = FeedbackRepo(session_factory)

    record = _record(feedback_id="fb-001")
    await repo.save(
        record=record,
        prompt_versions=_PROMPT_VERSIONS,
        request_id="req-001",
    )

    matches = await repo.find_relevant(domain_tag=record.domain_tag)
    assert len(matches) == 1
    fs = matches[0]
    assert fs.corrected_field == record.corrected_field
    assert fs.before == record.before
    assert fs.after == record.after
    assert fs.reason == record.reason
    assert fs.domain_tag == record.domain_tag
    assert 0.0 <= fs.relevance_score <= 1.0


@pytest.mark.asyncio
async def test_feedback_repo_find_relevant_returns_at_most_k_rows(
    session_factory: async_sessionmaker[AsyncSession],
) -> None:
    repo = FeedbackRepo(session_factory)

    for i in range(8):
        await repo.save(
            record=_record(feedback_id=f"fb-bulk-{i:02d}"),
            prompt_versions=_PROMPT_VERSIONS,
            request_id=f"req-{i:02d}",
        )
        await asyncio.sleep(0.001)

    matches = await repo.find_relevant(domain_tag=DomainTag.CELL_BIOLOGY_CRYOPRESERVATION, k=5)
    assert len(matches) == 5

    matches_three = await repo.find_relevant(
        domain_tag=DomainTag.CELL_BIOLOGY_CRYOPRESERVATION, k=3
    )
    assert len(matches_three) == 3


@pytest.mark.asyncio
async def test_feedback_repo_find_relevant_filters_by_domain_tag(
    session_factory: async_sessionmaker[AsyncSession],
) -> None:
    repo = FeedbackRepo(session_factory)

    await repo.save(
        record=_record(
            feedback_id="fb-cryo-1",
            domain_tag=DomainTag.CELL_BIOLOGY_CRYOPRESERVATION,
            after="Sigma-Aldrich trehalose",
        ),
        prompt_versions=_PROMPT_VERSIONS,
        request_id="req-c1",
    )
    await repo.save(
        record=_record(
            feedback_id="fb-bio-1",
            domain_tag=DomainTag.DIAGNOSTICS_BIOSENSOR,
            after="Whatman grade-1 paper",
        ),
        prompt_versions=_PROMPT_VERSIONS,
        request_id="req-b1",
    )

    cryo = await repo.find_relevant(domain_tag=DomainTag.CELL_BIOLOGY_CRYOPRESERVATION)
    assert len(cryo) == 1
    assert cryo[0].after == "Sigma-Aldrich trehalose"

    bio = await repo.find_relevant(domain_tag=DomainTag.DIAGNOSTICS_BIOSENSOR)
    assert len(bio) == 1
    assert bio[0].after == "Whatman grade-1 paper"


@pytest.mark.asyncio
async def test_feedback_repo_find_relevant_unrelated_domain_returns_empty(
    session_factory: async_sessionmaker[AsyncSession],
) -> None:
    repo = FeedbackRepo(session_factory)

    await repo.save(
        record=_record(
            feedback_id="fb-cryo-only",
            domain_tag=DomainTag.CELL_BIOLOGY_CRYOPRESERVATION,
        ),
        prompt_versions=_PROMPT_VERSIONS,
        request_id="req-c-only",
    )

    matches = await repo.find_relevant(domain_tag=DomainTag.MICROBIOME_MOUSE_MODEL)
    assert matches == []


@pytest.mark.asyncio
async def test_feedback_repo_save_persists_schema_version_and_prompt_versions(
    session_factory: async_sessionmaker[AsyncSession],
) -> None:
    repo = FeedbackRepo(session_factory)

    record = _record(feedback_id="fb-meta-001")
    await repo.save(
        record=record,
        prompt_versions=_PROMPT_VERSIONS,
        request_id="req-meta",
    )

    row = await repo.get_row_by_id("fb-meta-001")
    assert row is not None
    assert row.schema_version == FEEDBACK_SCHEMA_VERSION
    assert row.prompt_versions == _PROMPT_VERSIONS
    assert row.request_id == "req-meta"
