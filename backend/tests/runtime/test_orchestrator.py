"""Tests for `app/runtime/orchestrator.py` (Step 33)."""

# Pydantic v2 coerces plain string URLs into `HttpUrl` at validation time,
# but the pydantic mypy plugin rejects `str` arguments to `HttpUrl` fields.
# mypy: disable-error-code="arg-type"

from __future__ import annotations

import json
import logging

import pytest

from app.agents.literature_qc import NoveltyClaim, ReferenceClaim
from app.api.errors import GroundingFailedRefused
from app.clients.openai_client import (
    ChatResult,
    FakeOpenAIClient,
    ParsedResult,
    TokenUsage,
)
from app.clients.tavily_client import FakeTavilyClient, TavilyHit, TavilySearchResult
from app.config.source_tiers import load_source_tiers
from app.observability.logging import configure_logging
from app.runtime.orchestrator import Orchestrator
from app.schemas.experiment_plan import (
    ExperimentPlan,
    GroundingSummary,
    Material,
    ProtocolStep,
    ValidationPlan,
)
from app.schemas.literature_qc import (
    LiteratureQCResult,
    NoveltyLabel,
    Reference,
    SourceTier,
)
from app.verification.catalog_resolver import FakeCatalogResolver
from app.verification.citation_resolver import CitationOutcome, FakeCitationResolver

NATURE_URL = "https://www.nature.com/articles/abc"


def _keyword_chat(content: str = "trehalose cryopreservation HeLa") -> ChatResult:
    return ChatResult(
        content=content,
        usage=TokenUsage(prompt_tokens=20, completion_tokens=10),
        model="gpt-4.1-mini",
    )


def _claim(novelty: NoveltyLabel, refs: list[ReferenceClaim]) -> ParsedResult[NoveltyClaim]:
    return ParsedResult(
        parsed=NoveltyClaim(novelty=novelty, references=refs, confidence=0.9),
        usage=TokenUsage(prompt_tokens=120, completion_tokens=80),
        model="gpt-4.1-mini",
    )


def _verified(ref: Reference) -> CitationOutcome:
    return CitationOutcome(
        reference=ref.model_copy(
            update={
                "verified": True,
                "verification_url": ref.url,
                "confidence": "high",
            }
        ),
        tier_0_drop=False,
    )


def _experiment_plan_canned() -> ExperimentPlan:
    nature_ref = Reference(
        title="Nature paper",
        url=NATURE_URL,
        why_relevant="Direct prior art.",
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    )
    return ExperimentPlan(
        plan_id="plan-orch-001",
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


def _build_tavily_with_nature() -> FakeTavilyClient:
    return FakeTavilyClient(
        responses=[
            TavilySearchResult(
                query="verbatim",
                results=[
                    TavilyHit(url=NATURE_URL, title="Nature paper", snippet="...", score=0.9),
                ],
            ),
            TavilySearchResult(query="keywords", results=[]),
        ]
    )


@pytest.mark.asyncio
async def test_orchestrator_exact_match_skips_agent_3() -> None:
    openai = FakeOpenAIClient(
        chat_responses=[_keyword_chat()],
        parsed_responses=[
            _claim(
                NoveltyLabel.EXACT_MATCH,
                [
                    ReferenceClaim(
                        title="Nature paper",
                        url=NATURE_URL,
                        why_relevant="Exact prior art.",
                    )
                ],
            ),
        ],
    )
    tavily = _build_tavily_with_nature()
    nature_ref = Reference(
        title="Nature paper",
        url=NATURE_URL,
        why_relevant="Exact prior art.",
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    )
    citation_resolver = FakeCitationResolver(outcomes={NATURE_URL: _verified(nature_ref)})
    catalog_resolver = FakeCatalogResolver(outcomes={})

    orch = Orchestrator(
        openai=openai,
        tavily=tavily,
        citation_resolver=citation_resolver,
        catalog_resolver=catalog_resolver,
        source_tiers=load_source_tiers(),
    )
    response = await orch.run(hypothesis="x" * 20, request_id="r-orch-1")

    assert response.plan is None
    assert response.plan_id is None
    assert isinstance(response.qc, LiteratureQCResult)
    assert response.qc.novelty is NoveltyLabel.EXACT_MATCH
    assert all(c["kind"] != "parse" or c["model"] != "gpt-4.1" for c in openai.calls), (
        "Agent 3 (gpt-4.1) must not be called when novelty is exact_match"
    )


@pytest.mark.asyncio
async def test_orchestrator_full_path_runs_agent_3_when_continue() -> None:
    plan = _experiment_plan_canned()
    openai = FakeOpenAIClient(
        chat_responses=[_keyword_chat()],
        parsed_responses=[
            _claim(
                NoveltyLabel.SIMILAR_WORK_EXISTS,
                [
                    ReferenceClaim(
                        title="Nature paper",
                        url=NATURE_URL,
                        why_relevant="Direct prior art.",
                    )
                ],
            ),
            _parsed_plan(plan),
        ],
    )
    tavily = _build_tavily_with_nature()
    nature_ref = Reference(
        title="Nature paper",
        url=NATURE_URL,
        why_relevant="Direct prior art.",
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    )
    citation_resolver = FakeCitationResolver(outcomes={NATURE_URL: _verified(nature_ref)})
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

    orch = Orchestrator(
        openai=openai,
        tavily=tavily,
        citation_resolver=citation_resolver,
        catalog_resolver=catalog_resolver,
        source_tiers=load_source_tiers(),
    )
    response = await orch.run(
        hypothesis="Trehalose preserves HeLa viability better than sucrose at -80C.",
        request_id="r-orch-2",
    )

    assert response.plan is not None
    assert isinstance(response.plan, ExperimentPlan)
    assert all(m.verified for m in response.plan.materials)
    assert response.plan.references[0].verified is True
    assert response.grounding_summary.verified_count >= 2


@pytest.mark.asyncio
async def test_orchestrator_grounding_failed_refused_when_zero_verified() -> None:
    plan = _experiment_plan_canned()
    openai = FakeOpenAIClient(
        chat_responses=[_keyword_chat()],
        parsed_responses=[
            _claim(
                NoveltyLabel.SIMILAR_WORK_EXISTS,
                [
                    ReferenceClaim(
                        title="Nature paper",
                        url=NATURE_URL,
                        why_relevant="Direct prior art.",
                    )
                ],
            ),
            _parsed_plan(plan),
        ],
    )
    tavily = _build_tavily_with_nature()
    citation_resolver = FakeCitationResolver(
        outcomes={NATURE_URL: CitationOutcome(reference=None, tier_0_drop=False)},
        default=CitationOutcome(reference=None, tier_0_drop=False),
    )
    catalog_resolver = FakeCatalogResolver(outcomes={})

    orch = Orchestrator(
        openai=openai,
        tavily=tavily,
        citation_resolver=citation_resolver,
        catalog_resolver=catalog_resolver,
        source_tiers=load_source_tiers(),
    )
    with pytest.raises(GroundingFailedRefused):
        await orch.run(hypothesis="x" * 20, request_id="r-orch-3")


@pytest.mark.asyncio
async def test_orchestrator_emits_one_log_line_per_agent_call(
    caplog: pytest.LogCaptureFixture,
) -> None:
    configure_logging()
    plan = _experiment_plan_canned()
    openai = FakeOpenAIClient(
        chat_responses=[_keyword_chat()],
        parsed_responses=[
            _claim(
                NoveltyLabel.SIMILAR_WORK_EXISTS,
                [
                    ReferenceClaim(
                        title="Nature paper",
                        url=NATURE_URL,
                        why_relevant="Direct prior art.",
                    )
                ],
            ),
            _parsed_plan(plan),
        ],
    )
    tavily = _build_tavily_with_nature()
    nature_ref = Reference(
        title="Nature paper",
        url=NATURE_URL,
        why_relevant="Direct prior art.",
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    )
    citation_resolver = FakeCitationResolver(outcomes={NATURE_URL: _verified(nature_ref)})
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

    orch = Orchestrator(
        openai=openai,
        tavily=tavily,
        citation_resolver=citation_resolver,
        catalog_resolver=catalog_resolver,
        source_tiers=load_source_tiers(),
    )

    with caplog.at_level(logging.INFO, logger="agent"):
        await orch.run(hypothesis="x" * 20, request_id="r-orch-4")

    agent_lines = [
        json.loads(rec.getMessage())
        for rec in caplog.records
        if "agent.call.complete" in rec.getMessage()
    ]
    agents = [line["agent"] for line in agent_lines]
    assert "literature_qc" in agents
    assert "experiment_planner" in agents
    assert all(line["request_id"] == "r-orch-4" for line in agent_lines)
