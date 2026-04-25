"""Tests for the POST /generate-plan input contract (Step 12) and the
QC-only short-circuit route wiring (Step 25)."""

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
from pydantic import ValidationError

from app.agents.literature_qc import NoveltyClaim, ReferenceClaim
from app.api import deps as api_deps
from app.clients.openai_client import (
    ChatResult,
    FakeOpenAIClient,
    ParsedResult,
    TokenUsage,
)
from app.clients.tavily_client import FakeTavilyClient, TavilyHit, TavilySearchResult
from app.config.source_tiers import load_source_tiers
from app.prompts.loader import prompt_versions
from app.schemas.errors import ErrorCode
from app.schemas.hypothesis import GeneratePlanRequest
from app.schemas.literature_qc import NoveltyLabel, Reference, SourceTier
from app.verification.citation_resolver import CitationOutcome, FakeCitationResolver

NATURE_URL = "https://www.nature.com/articles/s41586-020-2649-2"


def test_generate_plan_request_accepts_valid_hypothesis() -> None:
    body = GeneratePlanRequest(
        hypothesis="Trehalose preserves HeLa viability better than sucrose at -80C.",
    )
    assert body.hypothesis.startswith("Trehalose")


def test_generate_plan_request_rejects_too_short_hypothesis() -> None:
    with pytest.raises(ValidationError):
        GeneratePlanRequest(hypothesis="too short")


def test_generate_plan_request_rejects_too_long_hypothesis() -> None:
    with pytest.raises(ValidationError):
        GeneratePlanRequest(hypothesis="x" * 2001)


def _exact_match_parsed() -> ParsedResult[NoveltyClaim]:
    claim = NoveltyClaim(
        novelty=NoveltyLabel.EXACT_MATCH,
        references=[
            ReferenceClaim(
                title="Identical paper",
                url=NATURE_URL,
                why_relevant="Same hypothesis already published.",
            )
        ],
        confidence=0.95,
    )
    return ParsedResult(
        parsed=claim,
        usage=TokenUsage(prompt_tokens=120, completion_tokens=80),
        model="gpt-4.1-mini",
    )


def _fake_clients() -> tuple[FakeOpenAIClient, FakeTavilyClient, FakeCitationResolver]:
    tavily = FakeTavilyClient(
        responses=[
            TavilySearchResult(
                query="verbatim",
                results=[
                    TavilyHit(url=NATURE_URL, title="Identical paper", snippet="...", score=0.95),
                ],
            ),
            TavilySearchResult(query="keywords", results=[]),
        ]
    )
    openai = FakeOpenAIClient(
        chat_responses=[
            ChatResult(
                content="alpha beta gamma",
                usage=TokenUsage(prompt_tokens=20, completion_tokens=10),
                model="gpt-4.1-mini",
            )
        ],
        parsed_responses=[_exact_match_parsed()],
    )
    nature_ref = Reference(
        title="Identical paper",
        url=NATURE_URL,
        why_relevant="Same hypothesis already published.",
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    )
    resolver = FakeCitationResolver(
        outcomes={
            NATURE_URL: CitationOutcome(
                reference=nature_ref.model_copy(
                    update={
                        "verified": True,
                        "verification_url": nature_ref.url,
                        "confidence": "high",
                    }
                ),
                tier_0_drop=False,
            )
        }
    )
    return openai, tavily, resolver


@pytest_asyncio.fixture
async def exact_match_app(monkeypatch: pytest.MonkeyPatch) -> AsyncIterator[FastAPI]:
    """Build the app with fake runtime dependencies wired in."""

    from app.main import create_app

    openai, tavily, resolver = _fake_clients()
    source_tiers = load_source_tiers()

    monkeypatch.setattr(api_deps, "build_openai_client", lambda settings: openai)
    monkeypatch.setattr(api_deps, "build_tavily_client", lambda settings, source_tiers: tavily)
    monkeypatch.setattr(api_deps, "build_citation_resolver", lambda source_tiers: resolver)
    _ = source_tiers  # kept for parity with the production resolver wiring

    app = create_app()
    async with app.router.lifespan_context(app):
        yield app


@pytest.mark.asyncio
async def test_generate_plan_exact_match_returns_qc_only_response(
    exact_match_app: FastAPI,
) -> None:
    transport = ASGITransport(app=exact_match_app, raise_app_exceptions=False)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            "/generate-plan",
            json={
                "hypothesis": ("Trehalose preserves HeLa viability better than sucrose at -80C."),
            },
        )

    assert response.status_code == 200
    body = response.json()
    assert body["plan"] is None
    assert body["plan_id"] is None
    assert body["qc"]["novelty"] == NoveltyLabel.EXACT_MATCH.value
    assert body["request_id"]


@pytest.mark.asyncio
async def test_generate_plan_response_includes_prompt_versions_for_role_files(
    exact_match_app: FastAPI,
) -> None:
    transport = ASGITransport(app=exact_match_app, raise_app_exceptions=False)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            "/generate-plan",
            json={
                "hypothesis": ("Trehalose preserves HeLa viability better than sucrose at -80C."),
            },
        )

    assert response.status_code == 200
    body = response.json()
    assert body["prompt_versions"] == prompt_versions()
    expected_keys = {
        "literature_qc.md",
        "feedback_relevance.md",
        "experiment_planner.md",
    }
    assert set(body["prompt_versions"].keys()) == expected_keys


@pytest.mark.asyncio
async def test_generate_plan_validation_error_returns_422_with_error_response(
    exact_match_app: FastAPI,
) -> None:
    transport = ASGITransport(app=exact_match_app, raise_app_exceptions=False)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            "/generate-plan",
            json={"hypothesis": "too short"},
        )

    assert response.status_code == 422
    body = response.json()
    assert body["code"] == ErrorCode.VALIDATION_ERROR.value
    assert body["request_id"]
