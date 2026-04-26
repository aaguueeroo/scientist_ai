"""TDD: plan-review envelope on `POST /feedback` + `GET /feedback` (A1)."""

from __future__ import annotations

from collections.abc import AsyncIterator

import pytest
import pytest_asyncio
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

import app.api.deps as api_deps
from app.clients.openai_client import FakeOpenAIClient
from app.clients.tavily_client import FakeTavilyClient, TavilySearchResult
from app.main import create_app
from app.schemas.feedback import DomainTag
from app.storage.models import FeedbackRow
from app.verification.catalog_resolver import FakeCatalogResolver
from app.verification.citation_resolver import FakeCitationResolver

from tests.api.test_feedback import _patch_in_memory_storage  # noqa: PLC2701


def _min_original_plan() -> dict:
    return {
        "description": "A short plan summary.",
        "budget": {
            "total": 1000.0,
            "currency": "USD",
            "materials": [],
        },
        "time_plan": {
            "total_duration_seconds": 0,
            "steps": [
                {
                    "number": 1,
                    "duration_seconds": 0,
                    "name": "Run pilot experiment",
                    "description": "Details.",
                    "milestone": None,
                }
            ],
        },
    }


@pytest_asyncio.fixture
async def pr_app(monkeypatch: pytest.MonkeyPatch) -> AsyncIterator[FastAPI]:
    openai = FakeOpenAIClient(parsed_responses=[])
    tavily = FakeTavilyClient(responses=[TavilySearchResult(query="any", results=[])])
    monkeypatch.setattr(api_deps, "build_openai_client", lambda s: openai)
    monkeypatch.setattr(
        api_deps,
        "build_tavily_client",
        lambda s, st: tavily,
    )
    monkeypatch.setattr(
        api_deps,
        "build_citation_resolver",
        lambda st: FakeCitationResolver(outcomes={}),
    )
    monkeypatch.setattr(
        api_deps,
        "build_catalog_resolver",
        lambda st: FakeCatalogResolver(outcomes={}),
    )
    _patch_in_memory_storage(monkeypatch)
    app = create_app()
    async with app.router.lifespan_context(app):
        yield app


def test_looks_like_plan_review_and_parses() -> None:
    from app.schemas.feedback import PlanReviewEventIn, parse_post_feedback_json

    body = {
        "plan_id": "plan-pr-1",
        "id": "client-1",
        "created_at": "2026-04-26T22:10:00.000Z",
        "conversation_id": "c1",
        "query": "Does cold exposure improve X?",
        "original_plan": _min_original_plan(),
        "kind": "correction",
        "payload": {
            "target": "plan.description",
            "before": "a",
            "after": "b",
        },
    }
    p = parse_post_feedback_json(body)
    assert isinstance(p, PlanReviewEventIn)
    assert p.kind == "correction"


def test_parse_legacy_unchanged() -> None:
    from app.schemas.feedback import FeedbackRequest, parse_post_feedback_json

    body = {
        "plan_id": "plan-legacy",
        "domain_tag": DomainTag.OTHER.value,
        "corrected_field": "x",
        "before": "a",
        "after": "b",
        "reason": "r",
    }
    p = parse_post_feedback_json(body)
    assert isinstance(p, FeedbackRequest)


@pytest.mark.asyncio
async def test_post_feedback_accepts_plan_review_envelope(
    pr_app: FastAPI,
) -> None:
    transport = ASGITransport(app=pr_app, raise_app_exceptions=False)
    body = {
        "plan_id": "plan-pr-envelope-1",
        "id": "client-rev-1",
        "created_at": "2026-04-26T22:10:00.000Z",
        "conversation_id": "c1",
        "query": "Does cold exposure improve X?",
        "original_plan": _min_original_plan(),
        "kind": "correction",
        "payload": {
            "target": "plan.description",
            "before": "a",
            "after": "b",
        },
    }
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post("/feedback", json=body)

    assert response.status_code == 200, response.text
    out = response.json()
    assert out["accepted"] is True
    assert out.get("domain_tag") in (None, "null")
    assert "review" in out and out["review"] is not None
    assert out["review"]["id"] == out["feedback_id"]
    assert out["review"]["plan_id"] == "plan-pr-envelope-1"

    factory: async_sessionmaker[AsyncSession] = pr_app.state.db_session_factory
    async with factory() as session:
        row = (
            await session.execute(
                select(FeedbackRow).where(FeedbackRow.feedback_id == out["feedback_id"])
            )
        ).scalar_one()
    assert row.review_envelope is not None
    assert row.corrected_field == "__plan_review__"


@pytest.mark.asyncio
async def test_get_feedback_lists_plan_reviews(
    pr_app: FastAPI,
) -> None:
    transport = ASGITransport(app=pr_app, raise_app_exceptions=False)
    body = {
        "plan_id": "plan-list-1",
        "id": "c2",
        "created_at": "2026-04-26T22:10:00.000Z",
        "conversation_id": "c1",
        "query": "Q?",
        "original_plan": _min_original_plan(),
        "kind": "feedback",
        "payload": {"section": "steps", "polarity": "like"},
    }
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        post_r = await client.post("/feedback", json=body)
        assert post_r.status_code == 200
        get_r = await client.get("/feedback")

    assert get_r.status_code == 200
    data = get_r.json()
    assert "reviews" in data
    assert len(data["reviews"]) == 1
    assert data["reviews"][0]["kind"] == "feedback"
    assert data["reviews"][0]["id"].startswith("fb-")


@pytest.mark.asyncio
async def test_find_relevant_ignores_plan_review_rows(
    pr_app: FastAPI,
) -> None:
    from app.schemas.feedback import FeedbackRecord
    from app.storage.feedback_repo import FeedbackRepo
    from app.prompts.loader import prompt_versions

    factory: async_sessionmaker[AsyncSession] = pr_app.state.db_session_factory
    repo = FeedbackRepo(factory)
    rec = FeedbackRecord(
        feedback_id="fb-legacyonly",
        plan_id="plan-1",
        domain_tag=DomainTag.CELL_BIOLOGY_CRYOPRESERVATION,
        corrected_field="a.b",
        before="1",
        after="2",
        reason="r",
    )
    await repo.save(
        record=rec,
        prompt_versions=prompt_versions(),
        request_id="r1",
    )
    pr_body = {
        "plan_id": "plan-2",
        "id": "x",
        "created_at": "2026-04-26T22:10:00.000Z",
        "conversation_id": "c",
        "query": "q",
        "original_plan": _min_original_plan(),
        "kind": "comment",
        "payload": {
            "target": "plan.description",
            "quote": "a",
            "start": 0,
            "end": 1,
            "body": "note",
        },
    }
    transport = ASGITransport(app=pr_app, raise_app_exceptions=False)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        r = await client.post("/feedback", json=pr_body)
        assert r.status_code == 200

    matches = await repo.find_relevant(
        domain_tag=DomainTag.CELL_BIOLOGY_CRYOPRESERVATION, k=10
    )
    assert len(matches) == 1
    assert matches[0].corrected_field == "a.b"
