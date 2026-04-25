"""MIQE checklist support.

`uses_qpcr(plan)` scans an `ExperimentPlan` for qPCR-style techniques
(case-insensitive substring match against a small keyword set).
`populate_miqe_if_qpcr(plan)` returns a copy of the plan with a
`MIQECompliance` block on `validation` when qPCR is in use, or leaves
it `None` otherwise. The compliance block produced here is a
deterministic skeleton (`status="missing"` for every category) — the
runtime orchestrator will let Agent 3 fill in the prose, but the
schema-shape guarantee is enforced by code.
"""

from __future__ import annotations

from app.schemas.experiment_plan import (
    ExperimentPlan,
    MIQECategory,
    MIQECategoryStatus,
    MIQECompliance,
)

_QPCR_KEYWORDS: tuple[str, ...] = (
    "qpcr",
    "rt-qpcr",
    "rtqpcr",
    "real-time pcr",
    "realtime pcr",
    "real time pcr",
    "taqman",
    "sybr green",
)


def uses_qpcr(plan: ExperimentPlan) -> bool:
    """True iff any protocol step or material name matches a qPCR keyword."""

    haystacks: list[str] = []
    for step in plan.protocol:
        haystacks.append(step.technique.lower())
        haystacks.append((step.description or "").lower())
    for material in plan.materials:
        haystacks.append(material.reagent.lower())
        if material.notes is not None:
            haystacks.append(material.notes.lower())

    for blob in haystacks:
        for keyword in _QPCR_KEYWORDS:
            if keyword in blob:
                return True
    return False


def build_miqe_compliance(
    status: MIQECategoryStatus = MIQECategoryStatus.MISSING,
    notes: str = "",
) -> MIQECompliance:
    """Return a deterministic 9-category MIQE block; default `status=missing`."""

    cat = MIQECategory(status=status, notes=notes)
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


def populate_miqe_if_qpcr(plan: ExperimentPlan) -> ExperimentPlan:
    """Attach an `MIQECompliance` skeleton to `validation` when qPCR is in use."""

    if not uses_qpcr(plan):
        return plan
    if plan.validation.miqe_compliance is not None:
        return plan
    new_validation = plan.validation.model_copy(update={"miqe_compliance": build_miqe_compliance()})
    return plan.model_copy(update={"validation": new_validation})
