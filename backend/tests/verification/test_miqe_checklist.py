"""Tests for `app/verification/miqe_checklist.py` (Step 32)."""

# Pydantic v2 coerces plain string URLs into `HttpUrl` at validation time,
# but the pydantic mypy plugin rejects `str` arguments to `HttpUrl` fields.
# mypy: disable-error-code="arg-type"

from __future__ import annotations

from app.schemas.experiment_plan import (
    Budget,
    BudgetLineItem,
    ExperimentPlan,
    GroundingSummary,
    Material,
    MIQECompliance,
    ProtocolStep,
    ValidationPlan,
)
from app.schemas.literature_qc import NoveltyLabel, SourceTier
from app.verification.miqe_checklist import (
    build_miqe_compliance,
    populate_miqe_if_qpcr,
    uses_qpcr,
)


def _plan(
    *,
    protocol: list[ProtocolStep] | None = None,
    materials: list[Material] | None = None,
    validation: ValidationPlan | None = None,
) -> ExperimentPlan:
    return ExperimentPlan(
        plan_id="plan-miqe",
        hypothesis="A short hypothesis.",
        novelty=NoveltyLabel.SIMILAR_WORK_EXISTS,
        protocol=protocol or [],
        materials=materials or [],
        budget=Budget(
            items=[BudgetLineItem(label="MIQE test budget", cost_usd=1.0)],
            total_usd=1.0,
        ),
        validation=validation or ValidationPlan(),
        grounding_summary=GroundingSummary(verified_count=0, unverified_count=0),
    )


def test_miqe_uses_qpcr_returns_true_for_protocol_with_rt_qpcr_step() -> None:
    plan = _plan(
        protocol=[
            ProtocolStep(
                order=1,
                technique="Cell culture",
                tier=SourceTier.TIER_1_PEER_REVIEWED,
            ),
            ProtocolStep(
                order=2,
                technique="RT-qPCR",
                description="Quantify CRP transcripts.",
                tier=SourceTier.TIER_1_PEER_REVIEWED,
            ),
        ]
    )
    assert uses_qpcr(plan) is True


def test_miqe_uses_qpcr_returns_false_for_sporomusa_fixture() -> None:
    plan = _plan(
        protocol=[
            ProtocolStep(
                order=1,
                technique="Bioelectrochemical reactor setup",
                description="Wire S. ovata to cathode.",
                tier=SourceTier.TIER_1_PEER_REVIEWED,
            ),
            ProtocolStep(
                order=2,
                technique="Acetate quantification by HPLC",
                description="Measure acetate yield.",
                tier=SourceTier.TIER_1_PEER_REVIEWED,
            ),
        ]
    )
    assert uses_qpcr(plan) is False


def test_miqe_compliance_populated_for_crp_biosensor_fixture() -> None:
    plan = _plan(
        protocol=[
            ProtocolStep(
                order=1,
                technique="Paper substrate fabrication",
                tier=SourceTier.TIER_1_PEER_REVIEWED,
            ),
            ProtocolStep(
                order=2,
                technique="qPCR validation",
                description="Validate CRP biosensor with qPCR readout.",
                tier=SourceTier.TIER_1_PEER_REVIEWED,
            ),
        ]
    )
    populated = populate_miqe_if_qpcr(plan)
    assert populated.validation.miqe_compliance is not None
    assert isinstance(populated.validation.miqe_compliance, MIQECompliance)
    block = build_miqe_compliance()
    assert isinstance(block, MIQECompliance)


def test_miqe_compliance_remains_none_for_sporomusa_ovata_fixture() -> None:
    plan = _plan(
        protocol=[
            ProtocolStep(
                order=1,
                technique="Bioelectrochemical reactor setup",
                tier=SourceTier.TIER_1_PEER_REVIEWED,
            ),
        ]
    )
    populated = populate_miqe_if_qpcr(plan)
    assert populated.validation.miqe_compliance is None
