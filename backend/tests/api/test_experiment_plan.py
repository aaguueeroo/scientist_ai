"""Tests for `POST /literature-review` + `POST /experiment-plan` (Steps 12, 25, 34)."""

# Pydantic v2 coerces plain string URLs into `HttpUrl` at validation time,
# but the pydantic mypy plugin synthesises strict `__init__` signatures that
# reject `str`. Test fixtures here pass literal URLs as `str`; this
# file-level directive silences the resulting `[arg-type]` false positives.
# mypy: disable-error-code="arg-type"

from __future__ import annotations

import json
import logging
from collections.abc import AsyncIterator
from typing import Any

import pytest
import pytest_asyncio
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from pydantic import ValidationError
from sqlalchemy.ext.asyncio import create_async_engine

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
from app.observability.logging import configure_logging
from app.prompts.loader import prompt_versions
from app.schemas.errors import ErrorCode
from app.schemas.experiment_plan import (
    ExperimentPlan,
    GroundingSummary,
    Material,
    ProtocolStep,
    ValidationPlan,
)
from app.schemas.literature_qc import NoveltyLabel, Reference, SourceTier
from app.schemas.pipeline_http import ExperimentPlanHttpRequest
from app.storage import db as storage_db
from app.verification.catalog_resolver import FakeCatalogResolver
from app.verification.citation_resolver import CitationOutcome, FakeCitationResolver

NATURE_URL = "https://www.nature.com/articles/s41586-020-2649-2"

# Shared across API tests: must match between literature + experiment post bodies.
SAMPLE_HYPOTHESIS = "Trehalose preserves HeLa viability better than sucrose at -80C."


def literature_review_id_from_sse(sse_text: str) -> str:
    last: str | None = None
    for line in sse_text.splitlines():
        if not line.startswith("data:"):
            continue
        raw = line.removeprefix("data:").strip()
        if not raw:
            continue
        env = json.loads(raw)
        data = env.get("data")
        if isinstance(data, dict) and "literature_review_id" in data:
            last = data["literature_review_id"]
    assert last is not None, f"no literature_review_id in SSE: {sse_text!r}"
    return last


async def post_literature_then_experiment_plan(
    client: AsyncClient,
    *,
    query: str,
    lit_request_id: str = "test-lit-client-req",
) -> dict[str, Any]:
    lit = await client.post(
        "/literature-review",
        json={"query": query, "request_id": lit_request_id},
    )
    assert lit.status_code == 200, lit.text
    lr_id = literature_review_id_from_sse(lit.text)
    exp = await client.post(
        "/experiment-plan",
        json={"query": query, "literature_review_id": lr_id},
    )
    assert exp.status_code == 200, exp.text
    body: dict[str, Any] = exp.json()
    return body


def test_experiment_plan_request_accepts_valid_body() -> None:
    body = ExperimentPlanHttpRequest(
        query=SAMPLE_HYPOTHESIS,
        literature_review_id="lr-abc",
    )
    assert body.literature_review_id == "lr-abc"


def test_experiment_plan_request_rejects_too_short_query() -> None:
    with pytest.raises(ValidationError):
        ExperimentPlanHttpRequest(query="too short", literature_review_id="lr-1")


def test_experiment_plan_request_rejects_too_long_query() -> None:
    with pytest.raises(ValidationError):
        ExperimentPlanHttpRequest(query="x" * 2001, literature_review_id="lr-1")


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


def _patch_in_memory_storage(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        storage_db,
        "create_engine",
        lambda settings: create_async_engine("sqlite+aiosqlite:///:memory:", future=True),
    )


@pytest_asyncio.fixture
async def exact_match_app(monkeypatch: pytest.MonkeyPatch) -> AsyncIterator[FastAPI]:
    """Build the app with fake runtime dependencies wired in."""

    from app.main import create_app

    openai, tavily, resolver = _fake_clients()
    source_tiers = load_source_tiers()

    monkeypatch.setattr(api_deps, "build_openai_client", lambda settings: openai)
    monkeypatch.setattr(api_deps, "build_tavily_client", lambda settings, source_tiers: tavily)
    monkeypatch.setattr(api_deps, "build_citation_resolver", lambda source_tiers: resolver)
    _patch_in_memory_storage(monkeypatch)
    _ = source_tiers  # kept for parity with the production resolver wiring

    app = create_app()
    async with app.router.lifespan_context(app):
        yield app


@pytest.mark.asyncio
async def test_experiment_plan_exact_match_returns_qc_only_response(
    exact_match_app: FastAPI,
) -> None:
    transport = ASGITransport(app=exact_match_app, raise_app_exceptions=False)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        body = await post_literature_then_experiment_plan(client, query=SAMPLE_HYPOTHESIS)

    assert body["plan"] is None
    assert body["plan_id"] is None
    assert body["qc"]["novelty"] == NoveltyLabel.EXACT_MATCH.value
    assert body["request_id"]


@pytest.mark.asyncio
async def test_experiment_plan_response_includes_prompt_versions_for_role_files(
    exact_match_app: FastAPI,
) -> None:
    transport = ASGITransport(app=exact_match_app, raise_app_exceptions=False)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        body = await post_literature_then_experiment_plan(client, query=SAMPLE_HYPOTHESIS)

    assert body["prompt_versions"] == prompt_versions()
    expected_keys = {
        "literature_qc.md",
        "feedback_relevance.md",
        "experiment_planner.md",
    }
    assert set(body["prompt_versions"].keys()) == expected_keys


@pytest.mark.asyncio
async def test_experiment_plan_validation_error_returns_422_with_error_response(
    exact_match_app: FastAPI,
) -> None:
    transport = ASGITransport(app=exact_match_app, raise_app_exceptions=False)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            "/experiment-plan",
            json={"query": "too short", "literature_review_id": "lr-1"},
        )

    assert response.status_code == 422
    body = response.json()
    assert body["code"] == ErrorCode.VALIDATION_ERROR.value
    assert body["request_id"]


# ---------- Step 34: full-orchestrator path ----------


def _similar_claim_parsed() -> ParsedResult[NoveltyClaim]:
    claim = NoveltyClaim(
        novelty=NoveltyLabel.SIMILAR_WORK_EXISTS,
        references=[
            ReferenceClaim(
                title="Nature paper",
                url=NATURE_URL,
                why_relevant="Direct prior art for the trehalose hypothesis.",
            )
        ],
        confidence=0.82,
    )
    return ParsedResult(
        parsed=claim,
        usage=TokenUsage(prompt_tokens=120, completion_tokens=80),
        model="gpt-4.1-mini",
    )


def _experiment_plan_canned() -> ExperimentPlan:
    nature_ref = Reference(
        title="Nature paper",
        url=NATURE_URL,
        why_relevant="Direct prior art for the trehalose hypothesis.",
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    )
    return ExperimentPlan(
        plan_id="plan-route-001",
        hypothesis=SAMPLE_HYPOTHESIS,
        novelty=NoveltyLabel.SIMILAR_WORK_EXISTS,
        references=[nature_ref],
        protocol=[
            ProtocolStep(
                order=1,
                technique="Cell culture",
                source_url=NATURE_URL,
                tier=SourceTier.TIER_1_PEER_REVIEWED,
            )
        ],
        materials=[
            Material(
                reagent="Trehalose dihydrate",
                vendor="Sigma-Aldrich",
                sku="T9531",
                tier=SourceTier.TIER_1_PEER_REVIEWED,
            ),
            Material(
                reagent="DMEM cell-culture medium",
                vendor="Thermo Fisher",
                sku="11965092",
                tier=SourceTier.TIER_1_PEER_REVIEWED,
            ),
        ],
        validation=ValidationPlan(
            success_metrics=["viability >= 80%"],
            failure_metrics=["membrane integrity drop >= 20%"],
        ),
        grounding_summary=GroundingSummary(verified_count=0, unverified_count=1),
    )


def _parsed_plan(plan: ExperimentPlan) -> ParsedResult[ExperimentPlan]:
    return ParsedResult(
        parsed=plan,
        usage=TokenUsage(prompt_tokens=200, completion_tokens=400),
        model="gpt-4.1",
    )


def _verified_nature_outcome() -> CitationOutcome:
    nature_ref = Reference(
        title="Nature paper",
        url=NATURE_URL,
        why_relevant="Direct prior art for the trehalose hypothesis.",
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    )
    return CitationOutcome(
        reference=nature_ref.model_copy(
            update={
                "verified": True,
                "verification_url": nature_ref.url,
                "confidence": "high",
            }
        ),
        tier_0_drop=False,
    )


def _full_path_clients(
    *,
    citation_resolver: FakeCitationResolver,
    catalog_resolver: FakeCatalogResolver,
) -> tuple[FakeOpenAIClient, FakeTavilyClient, FakeCitationResolver, FakeCatalogResolver]:
    tavily = FakeTavilyClient(
        responses=[
            TavilySearchResult(
                query="verbatim",
                results=[
                    TavilyHit(
                        url=NATURE_URL,
                        title="Nature paper",
                        snippet="...",
                        score=0.9,
                    ),
                ],
            ),
            TavilySearchResult(query="keywords", results=[]),
        ]
    )
    plan = _experiment_plan_canned()
    openai = FakeOpenAIClient(
        chat_responses=[
            ChatResult(
                content="trehalose cryopreservation HeLa",
                usage=TokenUsage(prompt_tokens=20, completion_tokens=10),
                model="gpt-4.1-mini",
            )
        ],
        parsed_responses=[_similar_claim_parsed(), _parsed_plan(plan)],
    )
    return openai, tavily, citation_resolver, catalog_resolver


@pytest_asyncio.fixture
async def full_path_app(monkeypatch: pytest.MonkeyPatch) -> AsyncIterator[FastAPI]:
    """Build the app wired for the full-orchestrator (continue) path."""

    from app.main import create_app

    citation_resolver = FakeCitationResolver(outcomes={NATURE_URL: _verified_nature_outcome()})
    trehalose_verified = Material(
        reagent="Trehalose dihydrate",
        vendor="Sigma-Aldrich",
        sku="T9531",
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    ).model_copy(
        update={
            "verified": True,
            "verification_url": "https://www.sigmaaldrich.com/US/en/product/sigma/T9531",
            "confidence": "high",
        }
    )
    dmem_verified = Material(
        reagent="DMEM cell-culture medium",
        vendor="Thermo Fisher",
        sku="11965092",
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    ).model_copy(
        update={
            "verified": True,
            "verification_url": "https://www.thermofisher.com/order/catalog/product/11965092",
            "confidence": "high",
        }
    )
    catalog_resolver = FakeCatalogResolver(
        outcomes={"T9531": trehalose_verified, "11965092": dmem_verified},
    )
    openai, tavily, citation_resolver, catalog_resolver = _full_path_clients(
        citation_resolver=citation_resolver,
        catalog_resolver=catalog_resolver,
    )

    monkeypatch.setattr(api_deps, "build_openai_client", lambda settings: openai)
    monkeypatch.setattr(
        api_deps,
        "build_tavily_client",
        lambda settings, source_tiers: tavily,
    )
    monkeypatch.setattr(
        api_deps,
        "build_citation_resolver",
        lambda source_tiers: citation_resolver,
    )
    monkeypatch.setattr(
        api_deps,
        "build_catalog_resolver",
        lambda source_tiers: catalog_resolver,
    )
    _patch_in_memory_storage(monkeypatch)

    _ = load_source_tiers()  # parity with production wiring

    app = create_app()
    async with app.router.lifespan_context(app):
        yield app


@pytest_asyncio.fixture
async def grounding_failed_app(monkeypatch: pytest.MonkeyPatch) -> AsyncIterator[FastAPI]:
    """Build the app where every reference / SKU comes back unverified."""

    from app.main import create_app

    citation_resolver = FakeCitationResolver(
        outcomes={NATURE_URL: CitationOutcome(reference=None, tier_0_drop=False)},
        default=CitationOutcome(reference=None, tier_0_drop=False),
    )
    catalog_resolver = FakeCatalogResolver(outcomes={})
    openai, tavily, citation_resolver, catalog_resolver = _full_path_clients(
        citation_resolver=citation_resolver,
        catalog_resolver=catalog_resolver,
    )

    monkeypatch.setattr(api_deps, "build_openai_client", lambda settings: openai)
    monkeypatch.setattr(
        api_deps,
        "build_tavily_client",
        lambda settings, source_tiers: tavily,
    )
    monkeypatch.setattr(
        api_deps,
        "build_citation_resolver",
        lambda source_tiers: citation_resolver,
    )
    monkeypatch.setattr(
        api_deps,
        "build_catalog_resolver",
        lambda source_tiers: catalog_resolver,
    )
    _patch_in_memory_storage(monkeypatch)

    app = create_app()
    async with app.router.lifespan_context(app):
        yield app


@pytest.mark.asyncio
async def test_experiment_plan_full_path_returns_plan_with_grounded_references(
    full_path_app: FastAPI,
) -> None:
    transport = ASGITransport(app=full_path_app, raise_app_exceptions=False)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        body = await post_literature_then_experiment_plan(client, query=SAMPLE_HYPOTHESIS)

    assert body["plan"] is not None
    assert body["plan_id"] == "plan-route-001"
    assert body["qc"]["novelty"] == NoveltyLabel.SIMILAR_WORK_EXISTS.value
    assert body["plan"]["references"][0]["verified"] is True
    assert all(m["verified"] is True for m in body["plan"]["materials"])
    assert body["grounding_summary"]["verified_count"] >= 2


@pytest.mark.asyncio
async def test_experiment_plan_grounding_failed_status(
    grounding_failed_app: FastAPI,
) -> None:
    transport = ASGITransport(app=grounding_failed_app, raise_app_exceptions=False)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        lit = await client.post(
            "/literature-review",
            json={"query": SAMPLE_HYPOTHESIS, "request_id": "a"},
        )
        assert lit.status_code == 200, lit.text
        lr = literature_review_id_from_sse(lit.text)
        response = await client.post(
            "/experiment-plan",
            json={"query": SAMPLE_HYPOTHESIS, "literature_review_id": lr},
        )

    assert response.status_code == 422
    res_body = response.json()
    assert res_body["code"] == ErrorCode.GROUNDING_FAILED_REFUSED.value
    assert res_body["request_id"]


@pytest.mark.asyncio
async def test_experiment_plan_response_carries_request_id_matching_log_line(
    full_path_app: FastAPI,
    caplog: pytest.LogCaptureFixture,
) -> None:
    configure_logging()
    transport = ASGITransport(app=full_path_app, raise_app_exceptions=False)

    with caplog.at_level(logging.INFO):
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            lit = await client.post(
                "/literature-review",
                json={"query": SAMPLE_HYPOTHESIS, "request_id": "a"},
            )
            assert lit.status_code == 200, lit.text
            lr = literature_review_id_from_sse(lit.text)
            response = await client.post(
                "/experiment-plan",
                json={"query": SAMPLE_HYPOTHESIS, "literature_review_id": lr},
                headers={"x-request-id": "req-route-34"},
            )

    assert response.status_code == 200
    body = response.json()
    assert body["request_id"] == "req-route-34"

    http_lines = [
        json.loads(rec.getMessage())
        for rec in caplog.records
        if "http.request.complete" in rec.getMessage()
    ]
    assert any(line["request_id"] == "req-route-34" for line in http_lines)
