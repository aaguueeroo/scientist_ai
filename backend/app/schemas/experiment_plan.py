"""Pydantic schemas for the experiment plan emitted by runtime Agent 3.

Per `docs/research.md` §8 every Material / ProtocolStep / Reference field
carries `tier`, `verified`, `verification_url`, `confidence`. The
`MIQECompliance` block (§15) covers the nine MIQE checklist categories
and is optional on `ValidationPlan` — only populated when the protocol
contains a `qPCR` / `RT-qPCR` step.
"""

from __future__ import annotations

from enum import StrEnum
from typing import Literal

from pydantic import BaseModel, Field, HttpUrl

from app.schemas.literature_qc import NoveltyLabel, Reference, SourceTier


class Material(BaseModel):
    """A reagent / consumable with supplier grounding."""

    reagent: str = Field(min_length=1, max_length=300)
    vendor: str | None = None
    sku: str | None = None
    qty: float | None = None
    qty_unit: str | None = None
    unit_cost_usd: float | None = None
    source_url: HttpUrl | None = None
    notes: str | None = Field(default=None, max_length=2000)
    tier: SourceTier
    verified: bool = False
    verification_url: HttpUrl | None = None
    confidence: Literal["high", "medium", "low"] = "low"


class ProtocolStep(BaseModel):
    """One ordered step in the experiment protocol."""

    order: int = Field(ge=1)
    technique: str = Field(min_length=1, max_length=120)
    description: str = Field(default="", max_length=4000)
    source_doi: str | None = None
    source_url: HttpUrl | None = None
    tier: SourceTier
    verified: bool = False
    verification_url: HttpUrl | None = None
    confidence: Literal["high", "medium", "low"] = "low"
    notes: str | None = Field(default=None, max_length=2000)


class BudgetLineItem(BaseModel):
    """One line of the experiment budget."""

    label: str = Field(min_length=1, max_length=200)
    cost_usd: float = Field(ge=0.0)


class Budget(BaseModel):
    """Aggregate budget; total is exposed explicitly so the LLM can echo it."""

    items: list[BudgetLineItem] = Field(default_factory=list)
    total_usd: float = Field(ge=0.0)
    currency: Literal["USD"] = "USD"


class TimelinePhase(BaseModel):
    """One phase of the timeline plan."""

    phase: str = Field(min_length=1, max_length=200)
    duration_days: int = Field(ge=0)
    depends_on: list[str] = Field(default_factory=list)


class MIQECategoryStatus(StrEnum):
    """Status of a single MIQE checklist category."""

    PRESENT = "present"
    PARTIAL = "partial"
    MISSING = "missing"


class MIQECategory(BaseModel):
    """One MIQE checklist category with status + free-text notes."""

    status: MIQECategoryStatus
    notes: str = Field(default="", max_length=2000)


class MIQECompliance(BaseModel):
    """The nine MIQE checklist categories, one entry per category.

    Source: Bustin S.A. et al. (2009) — DOI 10.1373/clinchem.2008.112797.
    """

    sample: MIQECategory
    nucleic_acid_extraction: MIQECategory
    reverse_transcription: MIQECategory
    qpcr_target_information: MIQECategory
    qpcr_oligonucleotides: MIQECategory
    qpcr_protocol: MIQECategory
    qpcr_validation: MIQECategory
    data_analysis: MIQECategory
    methodological_details: MIQECategory


class ValidationPlan(BaseModel):
    """How the experiment will be validated; MIQE block only when qPCR is used."""

    success_metrics: list[str] = Field(default_factory=list)
    failure_metrics: list[str] = Field(default_factory=list)
    miqe_compliance: MIQECompliance | None = None


class Risk(BaseModel):
    """A risk + mitigation entry."""

    description: str = Field(min_length=1, max_length=2000)
    likelihood: Literal["low", "medium", "high"] = "medium"
    mitigation: str = Field(default="", max_length=2000)
    compliance_note: str | None = Field(default=None, max_length=2000)


class GroundingSummary(BaseModel):
    """Aggregate grounding result reported alongside the plan."""

    verified_count: int = Field(ge=0)
    unverified_count: int = Field(ge=0)
    tier_0_drops: int = Field(default=0, ge=0)


class ExperimentPlan(BaseModel):
    """Top-level experiment plan emitted by runtime Agent 3."""

    plan_id: str = Field(min_length=1, max_length=200)
    hypothesis: str = Field(min_length=1, max_length=2000)
    novelty: NoveltyLabel
    references: list[Reference] = Field(default_factory=list)
    protocol: list[ProtocolStep] = Field(default_factory=list)
    materials: list[Material] = Field(default_factory=list)
    budget: Budget | None = None
    timeline: list[TimelinePhase] = Field(default_factory=list)
    validation: ValidationPlan
    risks: list[Risk] = Field(default_factory=list)
    confidence: Literal["high", "medium", "low"] = "low"
    grounding_summary: GroundingSummary
