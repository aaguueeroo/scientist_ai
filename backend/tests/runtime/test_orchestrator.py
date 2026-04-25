"""Tests for `app/runtime/orchestrator.py` (Steps 33 + 43)."""

# Pydantic v2 coerces plain string URLs into `HttpUrl` at validation time,
# but the pydantic mypy plugin rejects `str` arguments to `HttpUrl` fields.
# mypy: disable-error-code="arg-type"

from __future__ import annotations

import asyncio
import json
import logging
from collections.abc import AsyncIterator

import pytest
import pytest_asyncio
from pydantic import SecretStr

from app.agents.feedback_relevance import (
    DomainTagClaim,
    RelevanceClaim,
    RelevanceItem,
)
from app.agents.literature_qc import NoveltyClaim, ReferenceClaim
from app.api.errors import GroundingFailedRefused
from app.clients.openai_client import (
    ChatMessage,
    ChatResult,
    FakeOpenAIClient,
    ParsedResult,
    TokenUsage,
)
from app.clients.tavily_client import FakeTavilyClient, TavilyHit, TavilySearchResult
from app.config.settings import Settings
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
from app.schemas.feedback import DomainTag, FeedbackRecord
from app.schemas.literature_qc import (
    LiteratureQCResult,
    NoveltyLabel,
    Reference,
    SourceTier,
)
from app.storage import db as db_module
from app.storage.feedback_repo import FeedbackRepo
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


# ---------------------------------------------------------------------------
# Step 43 — Orchestrator wires Agent 2 (full path: 1 -> gate -> 2 -> 3)
# ---------------------------------------------------------------------------


def _settings() -> Settings:
    return Settings(
        OPENAI_API_KEY=SecretStr("sk-test"),
        TAVILY_API_KEY=SecretStr("tvly-test"),
        DATABASE_URL="sqlite+aiosqlite:///:memory:",
    )


_PROMPT_VERSIONS_AGENT2: dict[str, str] = {
    "literature_qc.md": "qc",
    "feedback_relevance.md": "fb",
    "experiment_planner.md": "ep",
}


@pytest_asyncio.fixture
async def feedback_repo() -> AsyncIterator[FeedbackRepo]:
    engine = db_module.create_engine(_settings())
    await db_module.create_all(engine)
    factory = db_module.async_session(engine)
    try:
        yield FeedbackRepo(factory)
    finally:
        await engine.dispose()


def _domain(tag: DomainTag) -> ParsedResult[DomainTagClaim]:
    return ParsedResult(
        parsed=DomainTagClaim(domain_tag=tag),
        usage=TokenUsage(prompt_tokens=20, completion_tokens=4),
        model="gpt-4.1-mini",
    )


def _rerank(items: list[RelevanceItem]) -> ParsedResult[RelevanceClaim]:
    return ParsedResult(
        parsed=RelevanceClaim(items=items),
        usage=TokenUsage(prompt_tokens=80, completion_tokens=40),
        model="gpt-4.1-mini",
    )


def _build_full_path_catalog_resolver() -> FakeCatalogResolver:
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
    return FakeCatalogResolver(
        outcomes={"T9531": trehalose_verified, "11965092": dmem_verified},
    )


async def _seed_correction(
    repo: FeedbackRepo,
    *,
    feedback_id: str,
    after: str = "Sigma-Aldrich trehalose",
) -> FeedbackRecord:
    record = FeedbackRecord(
        feedback_id=feedback_id,
        plan_id="plan-orch-001",
        domain_tag=DomainTag.CELL_BIOLOGY_CRYOPRESERVATION,
        corrected_field="materials[0].vendor",
        before="acme",
        after=after,
        reason="standard supplier per published protocol",
    )
    await repo.save(
        record=record,
        prompt_versions=_PROMPT_VERSIONS_AGENT2,
        request_id=f"req-{feedback_id}",
    )
    return record


@pytest.mark.asyncio
async def test_orchestrator_full_path_calls_agent_2_then_agent_3(
    feedback_repo: FeedbackRepo,
) -> None:
    await _seed_correction(feedback_repo, feedback_id="fb-orch-43-001")
    await asyncio.sleep(0.001)
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
            _domain(DomainTag.CELL_BIOLOGY_CRYOPRESERVATION),
            _rerank([RelevanceItem(feedback_id="cand-000", score=0.9)]),
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

    orch = Orchestrator(
        openai=openai,
        tavily=tavily,
        citation_resolver=citation_resolver,
        catalog_resolver=_build_full_path_catalog_resolver(),
        source_tiers=load_source_tiers(),
        feedback_repo=feedback_repo,
    )

    response = await orch.run(
        hypothesis="Trehalose preserves HeLa viability better than sucrose at -80C.",
        request_id="r-orch-43",
    )
    assert response.plan is not None

    parse_calls = [c for c in openai.calls if c["kind"] == "parse"]
    response_format_models = [c["response_format"].__name__ for c in parse_calls]
    qc_idx = response_format_models.index("NoveltyClaim")
    domain_idx = response_format_models.index("DomainTagClaim")
    rerank_idx = response_format_models.index("RelevanceClaim")
    plan_idx = response_format_models.index("ExperimentPlan")
    assert qc_idx < domain_idx < rerank_idx < plan_idx, (
        f"Agent ordering wrong: {response_format_models}"
    )


@pytest.mark.asyncio
async def test_orchestrator_exact_match_still_skips_agent_2_and_3(
    feedback_repo: FeedbackRepo,
) -> None:
    await _seed_correction(feedback_repo, feedback_id="fb-orch-skip-001")

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

    orch = Orchestrator(
        openai=openai,
        tavily=tavily,
        citation_resolver=citation_resolver,
        catalog_resolver=FakeCatalogResolver(outcomes={}),
        source_tiers=load_source_tiers(),
        feedback_repo=feedback_repo,
    )

    response = await orch.run(hypothesis="x" * 20, request_id="r-orch-43-skip")
    assert response.plan is None
    assert isinstance(response.qc, LiteratureQCResult)
    assert response.qc.novelty is NoveltyLabel.EXACT_MATCH

    parse_calls = [c for c in openai.calls if c["kind"] == "parse"]
    response_format_models = [c["response_format"].__name__ for c in parse_calls]
    assert response_format_models == ["NoveltyClaim"], (
        f"Only Agent 1's NoveltyClaim parse should fire on exact_match, "
        f"saw {response_format_models}"
    )


@pytest.mark.asyncio
async def test_orchestrator_passes_few_shots_into_agent_3_user_content_not_role(
    feedback_repo: FeedbackRepo,
) -> None:
    await _seed_correction(
        feedback_repo,
        feedback_id="fb-orch-fewshot-001",
        after="Sigma-Aldrich trehalose lot-XYZ",
    )
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
            _domain(DomainTag.CELL_BIOLOGY_CRYOPRESERVATION),
            _rerank([RelevanceItem(feedback_id="cand-000", score=0.9)]),
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

    orch = Orchestrator(
        openai=openai,
        tavily=tavily,
        citation_resolver=citation_resolver,
        catalog_resolver=_build_full_path_catalog_resolver(),
        source_tiers=load_source_tiers(),
        feedback_repo=feedback_repo,
    )
    await orch.run(
        hypothesis="Trehalose preserves HeLa viability better than sucrose at -80C.",
        request_id="r-orch-43-shot",
    )

    parse_calls = [c for c in openai.calls if c["kind"] == "parse"]
    plan_call = next(c for c in parse_calls if c["response_format"].__name__ == "ExperimentPlan")
    plan_messages: list[ChatMessage] = plan_call["messages"]
    system_msg, *rest = plan_messages
    assert system_msg.role == "system"
    assert "Sigma-Aldrich trehalose lot-XYZ" not in system_msg.content, (
        "Few-shot content must never be concatenated into the system role string."
    )
    assert any(
        msg.role == "user" and "Sigma-Aldrich trehalose lot-XYZ" in msg.content for msg in rest
    ), "Agent 3 must receive few-shot text in a `user` message, not the role."
