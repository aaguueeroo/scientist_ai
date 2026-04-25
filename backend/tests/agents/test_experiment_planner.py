"""Schema-shape tests for the experiment plan (Step 26) and Agent 3 (Step 28)."""

# Pydantic v2 coerces plain string URLs into `HttpUrl` at validation time,
# but the pydantic mypy plugin rejects `str` arguments to `HttpUrl` fields.
# Test fixtures here use literal URLs as `str`; silence the arg-type noise.
# mypy: disable-error-code="arg-type"

from __future__ import annotations

import json
import logging

import pytest
from pydantic import ValidationError

from app.agents.experiment_planner import ExperimentPlannerAgent
from app.api.errors import StructuredOutputInvalid
from app.clients.openai_client import (
    FakeOpenAIClient,
    ParsedResult,
    TokenUsage,
)
from app.observability.logging import configure_logging
from app.runtime.pipeline_state import PipelineState
from app.schemas.experiment_plan import (
    Budget,
    BudgetLineItem,
    ExperimentPlan,
    GroundingSummary,
    Material,
    MIQECategory,
    MIQECategoryStatus,
    MIQECompliance,
    ProtocolStep,
    Risk,
    TimelinePhase,
    ValidationPlan,
)
from app.schemas.literature_qc import (
    LiteratureQCResult,
    NoveltyLabel,
    Reference,
    SourceTier,
)


def _miqe_block_full(status: MIQECategoryStatus = MIQECategoryStatus.PRESENT) -> MIQECompliance:
    cat = MIQECategory(status=status)
    return MIQECompliance(
        sample=cat,
        nucleic_acid_extraction=cat,
        reverse_transcription=cat,
        qpcr_target_information=cat,
        qpcr_oligonucleotides=cat,
        qpcr_protocol=cat,
        qpcr_validation=cat,
        data_analysis=cat,
        methodological_details=cat,
    )


def test_experiment_plan_serializes_with_minimum_fields() -> None:
    plan = ExperimentPlan(
        plan_id="plan-001",
        hypothesis="Trehalose preserves HeLa viability better than sucrose at -80C.",
        novelty=NoveltyLabel.SIMILAR_WORK_EXISTS,
        validation=ValidationPlan(
            success_metrics=["viability >= 80% post-thaw"],
            failure_metrics=["membrane integrity drop >= 20%"],
        ),
        grounding_summary=GroundingSummary(verified_count=3, unverified_count=0),
    )
    payload = plan.model_dump(mode="json")
    assert payload["plan_id"] == "plan-001"
    assert payload["novelty"] == "similar_work_exists"
    assert payload["protocol"] == []
    assert payload["materials"] == []
    assert payload["references"] == []
    assert payload["risks"] == []
    assert payload["timeline"] == []
    assert payload["validation"]["miqe_compliance"] is None
    assert payload["confidence"] == "low"


def test_material_requires_tier_and_defaults_unverified() -> None:
    mat = Material(
        reagent="Trehalose",
        tier=SourceTier.TIER_2_PREPRINT_OR_COMMUNITY,
    )
    assert mat.verified is False
    assert mat.confidence == "low"
    assert mat.verification_url is None
    assert mat.sku is None

    with pytest.raises(ValidationError):
        Material(reagent="Missing tier")  # type: ignore[call-arg]


def test_protocol_step_requires_order_and_technique() -> None:
    step = ProtocolStep(
        order=1,
        technique="qPCR",
        description="Run qPCR for tight-junction transcripts.",
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    )
    assert step.order == 1
    assert step.technique == "qPCR"
    assert step.verified is False

    with pytest.raises(ValidationError):
        ProtocolStep(  # type: ignore[call-arg]
            description="Missing order and technique.",
            tier=SourceTier.TIER_1_PEER_REVIEWED,
        )


def test_validation_plan_miqe_compliance_optional_by_default() -> None:
    plan = ValidationPlan(
        success_metrics=["plate viable colonies"],
        failure_metrics=["zero growth"],
    )
    assert plan.miqe_compliance is None

    plan_with_miqe = ValidationPlan(
        success_metrics=["target detected"],
        failure_metrics=["no amplification"],
        miqe_compliance=_miqe_block_full(),
    )
    assert plan_with_miqe.miqe_compliance is not None


def test_miqe_compliance_required_fields_match_spec() -> None:
    expected = {
        "sample",
        "nucleic_acid_extraction",
        "reverse_transcription",
        "qpcr_target_information",
        "qpcr_oligonucleotides",
        "qpcr_protocol",
        "qpcr_validation",
        "data_analysis",
        "methodological_details",
    }
    actual = set(MIQECompliance.model_fields.keys())
    assert actual == expected

    with pytest.raises(ValidationError):
        MIQECompliance()  # type: ignore[call-arg]

    block = _miqe_block_full(MIQECategoryStatus.PARTIAL)
    dumped = block.model_dump(mode="json")
    for category in expected:
        assert dumped[category]["status"] == "partial"


def _ensure_helper_imports_used() -> None:
    """Keep imports referenced for static analyzers; values are used elsewhere."""

    _ = (Budget, BudgetLineItem, Risk, TimelinePhase)


# -- Step 28: ExperimentPlannerAgent against the fake OpenAI client. --


_NATURE_URL = "https://www.nature.com/articles/abc"


def _qc_result() -> LiteratureQCResult:
    return LiteratureQCResult(
        novelty=NoveltyLabel.SIMILAR_WORK_EXISTS,
        references=[
            Reference(
                title="Trehalose vs sucrose cryopreservation of HeLa",
                url=_NATURE_URL,
                why_relevant="Direct prior art for the hypothesis.",
                tier=SourceTier.TIER_1_PEER_REVIEWED,
                verified=True,
                verification_url=_NATURE_URL,
                confidence="high",
            )
        ],
        confidence="high",
        tier_0_drops=0,
    )


def _state(
    hypothesis: str = "Trehalose preserves HeLa viability better than sucrose at -80C.",
) -> PipelineState:
    return PipelineState(
        request_id="r-plan-1",
        hypothesis=hypothesis,
        qc_result=_qc_result(),
    )


def _plan(state: PipelineState) -> ExperimentPlan:
    qc = state.qc_result
    assert qc is not None
    return ExperimentPlan(
        plan_id="plan-stub-001",
        hypothesis=state.hypothesis,
        novelty=qc.novelty,
        references=list(qc.references),
        protocol=[
            ProtocolStep(
                order=1,
                technique="Cell culture",
                description="Seed HeLa cells and equilibrate.",
                tier=SourceTier.TIER_1_PEER_REVIEWED,
            )
        ],
        materials=[
            Material(
                reagent="Trehalose dihydrate",
                vendor="Sigma-Aldrich",
                sku="T9531",
                tier=SourceTier.TIER_1_PEER_REVIEWED,
            )
        ],
        validation=ValidationPlan(
            success_metrics=["viability >= 80% post-thaw"],
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


@pytest.mark.asyncio
async def test_experiment_planner_parses_valid_response_into_experiment_plan() -> None:
    state = _state()
    plan = _plan(state)
    openai = FakeOpenAIClient(parsed_responses=[_parsed_plan(plan)])
    agent = ExperimentPlannerAgent(openai=openai)

    result = await agent.run(state=state)

    assert isinstance(result, ExperimentPlan)
    assert result.hypothesis == state.hypothesis
    assert result.novelty == NoveltyLabel.SIMILAR_WORK_EXISTS
    assert len(result.materials) == 1
    assert result.materials[0].reagent == "Trehalose dihydrate"


@pytest.mark.asyncio
async def test_experiment_planner_rejects_schema_violating_response_raises_invalid() -> None:
    # plan-name: rejects_schema_violating_response_with_structured_output_invalid (Step 28)
    state = _state()
    boom_one = RuntimeError("malformed structured output 1")
    boom_two = RuntimeError("malformed structured output 2")
    openai = FakeOpenAIClient(parsed_responses=[boom_one, boom_two])
    agent = ExperimentPlannerAgent(openai=openai)

    with pytest.raises(StructuredOutputInvalid):
        await agent.run(state=state)


@pytest.mark.asyncio
async def test_experiment_planner_passes_role_and_user_as_separate_messages() -> None:
    state = _state()
    plan = _plan(state)
    openai = FakeOpenAIClient(parsed_responses=[_parsed_plan(plan)])
    agent = ExperimentPlannerAgent(openai=openai)

    await agent.run(state=state)

    parse_call = next(c for c in openai.calls if c["kind"] == "parse")
    messages = parse_call["messages"]
    assert len(messages) == 2
    assert messages[0].role == "system"
    assert messages[1].role == "user"
    assert (
        "Persona and scope" in messages[0].content
        or "experiment planner" in messages[0].content.lower()
    )
    assert state.hypothesis in messages[1].content
    assert state.hypothesis not in messages[0].content


@pytest.mark.asyncio
async def test_experiment_planner_emits_structured_log_line_with_required_keys(
    caplog: pytest.LogCaptureFixture,
) -> None:
    configure_logging()
    state = _state()
    plan = _plan(state)
    openai = FakeOpenAIClient(parsed_responses=[_parsed_plan(plan)])
    agent = ExperimentPlannerAgent(openai=openai)

    with caplog.at_level(logging.INFO, logger="agent"):
        await agent.run(state=state)

    line = next(rec for rec in caplog.records if "agent.call.complete" in rec.getMessage())
    payload = json.loads(line.getMessage())
    for key in (
        "agent",
        "model",
        "prompt_hash",
        "prompt_tokens",
        "completion_tokens",
        "latency_ms",
        "verified_count",
        "tier_0_drops",
        "request_id",
    ):
        assert key in payload, f"missing key: {key}"
    assert payload["agent"] == "experiment_planner"
    assert payload["model"] == "gpt-4.1"
    assert payload["request_id"] == state.request_id
