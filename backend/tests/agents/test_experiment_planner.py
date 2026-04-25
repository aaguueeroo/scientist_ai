"""Schema-shape tests for the experiment plan (Step 26).

Step 26 only pins the schema. The full agent-level tests
(structured-output round-trip, MIQE detection, etc.) land in later
steps (28, 32). These tests cover the five contracts called out in the
plan.
"""

from __future__ import annotations

import pytest
from pydantic import ValidationError

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
from app.schemas.literature_qc import NoveltyLabel, SourceTier


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
