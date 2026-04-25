"""Tests for `POST /feedback` (Step 44).

The route persists a `FeedbackRow` via `FeedbackRepo.save(...)` and
returns a `FeedbackResponse`. If `domain_tag` is omitted, the route
delegates to runtime Agent 2 to derive one.
"""

# Pydantic v2 coerces plain string URLs into `HttpUrl` at validation time,
# but the pydantic mypy plugin synthesises strict `__init__` signatures that
# reject `str`. Test fixtures here pass literal URLs as `str`; this
# file-level directive silences the resulting `[arg-type]` false positives.
# mypy: disable-error-code="arg-type"

from __future__ import annotations

from collections.abc import AsyncIterator

import pytest
import pytest_asyncio
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.agents.feedback_relevance import (
    DomainTagClaim,
)
from app.api import deps as api_deps
from app.clients.openai_client import (
    FakeOpenAIClient,
    ParsedResult,
    TokenUsage,
)
from app.clients.tavily_client import FakeTavilyClient, TavilySearchResult
from app.schemas.errors import ErrorCode
from app.schemas.feedback import DomainTag
from app.storage import db as storage_db
from app.storage.models import FEEDBACK_SCHEMA_VERSION, FeedbackRow
from app.verification.catalog_resolver import FakeCatalogResolver
from app.verification.citation_resolver import FakeCitationResolver


def _domain_response(tag: DomainTag) -> ParsedResult[DomainTagClaim]:
    return ParsedResult(
        parsed=DomainTagClaim(domain_tag=tag),
        usage=TokenUsage(prompt_tokens=20, completion_tokens=4),
        model="gpt-4.1-mini",
    )


def _patch_in_memory_storage(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        storage_db,
        "create_engine",
        lambda settings: create_async_engine("sqlite+aiosqlite:///:memory:", future=True),
    )


@pytest_asyncio.fixture
async def feedback_app(
    monkeypatch: pytest.MonkeyPatch,
) -> AsyncIterator[tuple[FastAPI, FakeOpenAIClient]]:
    """Build the app wired with a fake OpenAI client (so domain extraction is deterministic)."""

    from app.main import create_app

    openai = FakeOpenAIClient(
        parsed_responses=[
            _domain_response(DomainTag.CELL_BIOLOGY_CRYOPRESERVATION),
            _domain_response(DomainTag.CELL_BIOLOGY_CRYOPRESERVATION),
            _domain_response(DomainTag.CELL_BIOLOGY_CRYOPRESERVATION),
        ]
    )
    tavily = FakeTavilyClient(responses=[TavilySearchResult(query="any", results=[])])

    monkeypatch.setattr(api_deps, "build_openai_client", lambda settings: openai)
    monkeypatch.setattr(api_deps, "build_tavily_client", lambda settings, source_tiers: tavily)
    monkeypatch.setattr(
        api_deps,
        "build_citation_resolver",
        lambda source_tiers: FakeCitationResolver(outcomes={}),
    )
    monkeypatch.setattr(
        api_deps,
        "build_catalog_resolver",
        lambda source_tiers: FakeCatalogResolver(outcomes={}),
    )
    _patch_in_memory_storage(monkeypatch)

    app = create_app()
    async with app.router.lifespan_context(app):
        yield app, openai


@pytest.mark.asyncio
async def test_feedback_endpoint_persists_record_with_prompt_versions_and_schema_version(
    feedback_app: tuple[FastAPI, FakeOpenAIClient],
) -> None:
    app, _openai = feedback_app
    transport = ASGITransport(app=app, raise_app_exceptions=False)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            "/feedback",
            json={
                "plan_id": "plan-fb-001",
                "domain_tag": DomainTag.CELL_BIOLOGY_CRYOPRESERVATION.value,
                "corrected_field": "materials[0].vendor",
                "before": "acme",
                "after": "Sigma-Aldrich trehalose",
                "reason": "standard supplier per published protocol",
            },
        )

    assert response.status_code == 200, response.text
    body = response.json()
    feedback_id = body["feedback_id"]
    assert feedback_id

    factory: async_sessionmaker[AsyncSession] = app.state.db_session_factory
    async with factory() as session:
        row = (
            await session.execute(select(FeedbackRow).where(FeedbackRow.feedback_id == feedback_id))
        ).scalar_one()
    assert row.schema_version == FEEDBACK_SCHEMA_VERSION
    assert set(row.prompt_versions.keys()) == {
        "literature_qc.md",
        "feedback_relevance.md",
        "experiment_planner.md",
    }
    assert row.domain_tag == DomainTag.CELL_BIOLOGY_CRYOPRESERVATION.value
    assert row.before_text == "acme"
    assert row.after_text == "Sigma-Aldrich trehalose"


@pytest.mark.asyncio
async def test_feedback_endpoint_derives_domain_tag_when_missing(
    feedback_app: tuple[FastAPI, FakeOpenAIClient],
) -> None:
    app, openai = feedback_app
    transport = ASGITransport(app=app, raise_app_exceptions=False)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            "/feedback",
            json={
                "plan_id": "plan-fb-002",
                "corrected_field": "materials[0].vendor",
                "before": "acme",
                "after": "Sigma-Aldrich trehalose",
                "reason": "standard supplier per published protocol",
            },
        )

    assert response.status_code == 200, response.text
    body = response.json()
    assert body["domain_tag"] == DomainTag.CELL_BIOLOGY_CRYOPRESERVATION.value

    parse_calls = [c for c in openai.calls if c["kind"] == "parse"]
    assert any(c["response_format"].__name__ == "DomainTagClaim" for c in parse_calls), (
        "Agent 2's domain extraction must run when domain_tag is omitted."
    )


@pytest.mark.asyncio
async def test_feedback_endpoint_returns_validation_error_on_empty_corrected_field(
    feedback_app: tuple[FastAPI, FakeOpenAIClient],
) -> None:
    app, _openai = feedback_app
    transport = ASGITransport(app=app, raise_app_exceptions=False)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            "/feedback",
            json={
                "plan_id": "plan-fb-003",
                "domain_tag": DomainTag.OTHER.value,
                "corrected_field": "",
                "before": "acme",
                "after": "Sigma-Aldrich",
                "reason": "ok",
            },
        )

    assert response.status_code == 422
    body = response.json()
    assert body["code"] == ErrorCode.VALIDATION_ERROR.value
    assert body["request_id"]


@pytest.mark.asyncio
async def test_feedback_endpoint_response_includes_request_id(
    feedback_app: tuple[FastAPI, FakeOpenAIClient],
) -> None:
    app, _openai = feedback_app
    transport = ASGITransport(app=app, raise_app_exceptions=False)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            "/feedback",
            json={
                "plan_id": "plan-fb-004",
                "domain_tag": DomainTag.CELL_BIOLOGY_CRYOPRESERVATION.value,
                "corrected_field": "materials[0].vendor",
                "before": "acme",
                "after": "Sigma-Aldrich",
                "reason": "ok",
            },
        )

    assert response.status_code == 200
    body = response.json()
    assert body["request_id"]
    assert response.headers.get("x-request-id") == body["request_id"]
    assert body["accepted"] is True


@pytest.mark.asyncio
async def test_feedback_endpoint_accepts_provided_domain_tag_without_extra_llm_call(
    feedback_app: tuple[FastAPI, FakeOpenAIClient],
) -> None:
    """When the caller supplies `domain_tag`, Agent 2's domain extraction is skipped."""

    app, openai = feedback_app
    transport = ASGITransport(app=app, raise_app_exceptions=False)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            "/feedback",
            json={
                "plan_id": "plan-fb-005",
                "domain_tag": DomainTag.MICROBIOME_MOUSE_MODEL.value,
                "corrected_field": "materials[0].vendor",
                "before": "acme",
                "after": "Sigma-Aldrich",
                "reason": "ok",
            },
        )

    assert response.status_code == 200, response.text
    parse_calls_before = [c for c in openai.calls if c["kind"] == "parse"]
    assert all(c["response_format"].__name__ != "DomainTagClaim" for c in parse_calls_before), (
        "Agent 2 must not run when the caller already supplied a domain_tag."
    )
    # Other request types not exercised here, so RelevanceClaim should also be absent.
    assert all(c["response_format"].__name__ != "RelevanceClaim" for c in parse_calls_before)
