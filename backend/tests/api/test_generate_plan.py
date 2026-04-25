"""Tests for the POST /generate-plan input contract (Step 12), the QC-only
short-circuit route wiring (Step 25), and the full-orchestrator path
(Step 34)."""

# Pydantic v2 coerces plain string URLs into `HttpUrl` at validation time,
# but the pydantic mypy plugin synthesises strict `__init__` signatures that
# reject `str`. Test fixtures here pass literal URLs as `str`; this
# file-level directive silences the resulting `[arg-type]` false positives.
# mypy: disable-error-code="arg-type"

from __future__ import annotations

import json
import logging
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
from app.schemas.hypothesis import GeneratePlanRequest
from app.schemas.literature_qc import NoveltyLabel, Reference, SourceTier
from app.verification.catalog_resolver import FakeCatalogResolver
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
        hypothesis="Trehalose preserves HeLa viability better than sucrose at -80C.",
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

    app = create_app()
    async with app.router.lifespan_context(app):
        yield app


@pytest.mark.asyncio
async def test_generate_plan_full_path_returns_plan_with_grounded_references(
    full_path_app: FastAPI,
) -> None:
    transport = ASGITransport(app=full_path_app, raise_app_exceptions=False)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            "/generate-plan",
            json={
                "hypothesis": ("Trehalose preserves HeLa viability better than sucrose at -80C."),
            },
        )

    assert response.status_code == 200
    body = response.json()
    assert body["plan"] is not None
    assert body["plan_id"] == "plan-route-001"
    assert body["qc"]["novelty"] == NoveltyLabel.SIMILAR_WORK_EXISTS.value
    assert body["plan"]["references"][0]["verified"] is True
    assert all(m["verified"] is True for m in body["plan"]["materials"])
    assert body["grounding_summary"]["verified_count"] >= 2


@pytest.mark.asyncio
async def test_generate_plan_grounding_failed_returns_422_grounding_failed_refused(
    grounding_failed_app: FastAPI,
) -> None:
    transport = ASGITransport(app=grounding_failed_app, raise_app_exceptions=False)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            "/generate-plan",
            json={
                "hypothesis": ("Trehalose preserves HeLa viability better than sucrose at -80C."),
            },
        )

    assert response.status_code == 422
    body = response.json()
    assert body["code"] == ErrorCode.GROUNDING_FAILED_REFUSED.value
    assert body["request_id"]


@pytest.mark.asyncio
async def test_generate_plan_response_carries_request_id_matching_log_line(
    full_path_app: FastAPI,
    caplog: pytest.LogCaptureFixture,
) -> None:
    configure_logging()
    transport = ASGITransport(app=full_path_app, raise_app_exceptions=False)

    with caplog.at_level(logging.INFO):
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.post(
                "/generate-plan",
                json={
                    "hypothesis": (
                        "Trehalose preserves HeLa viability better than sucrose at -80C."
                    ),
                },
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
