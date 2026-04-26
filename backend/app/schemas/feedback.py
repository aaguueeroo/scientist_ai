"""Feedback schemas (Step 39).

These types describe the contract for `POST /feedback`, the persistence
record the feedback repo stores, and the few-shot examples Agent 2 hands to
Agent 3. The role string is loaded from disk; user content (the feedback
text) is never concatenated into a system prompt - it flows through these
typed shapes only.
"""

from __future__ import annotations

from enum import StrEnum

from typing import Any, cast

from pydantic import BaseModel, ConfigDict, Field


class DomainTag(StrEnum):
    """Closed enum of feedback buckets used by Agent 2 for retrieval."""

    DIAGNOSTICS_BIOSENSOR = "diagnostics-biosensor"
    MICROBIOME_MOUSE_MODEL = "microbiome-mouse-model"
    CELL_BIOLOGY_CRYOPRESERVATION = "cell-biology-cryopreservation"
    SYNTHETIC_BIOLOGY_BIOELECTRO = "synthetic-biology-bioelectro"
    OTHER = "other"


_FEEDBACK_REQUEST_EXAMPLE: dict[str, str] = {
    "plan_id": "plan-a1b2c3d-4e5f-6789-0abc-def012345678",
    "domain_tag": "cell-biology-cryopreservation",
    "corrected_field": "materials[0].vendor",
    "before": "Acme Cytoware",
    "after": "Sigma-Aldrich (SKU T9531) — verified 2024-11",
    "reason": "Per supplier datasheet and in-house SOP; previous vendor was placeholder.",
}

_FEEDBACK_RESPONSE_EXAMPLE: dict[str, str | bool] = {
    "feedback_id": "fb-6d7c8b9a0e1f2d3c4b5a68790fedcba1",
    "request_id": "0f1e2d3c4b5a69788796a5b4c3d2e1f0",
    "accepted": True,
    "domain_tag": "cell-biology-cryopreservation",
}


class FeedbackRequest(BaseModel):
    """Input DTO for `POST /feedback`."""

    model_config = ConfigDict(
        extra="forbid",
        json_schema_extra=cast(Any, {"example": _FEEDBACK_REQUEST_EXAMPLE}),
    )

    plan_id: str = Field(min_length=1, max_length=80)
    domain_tag: DomainTag | None = None
    corrected_field: str = Field(min_length=1, max_length=120)
    before: str = Field(max_length=4000)
    after: str = Field(max_length=4000)
    reason: str = Field(max_length=2000)


class FeedbackResponse(BaseModel):
    """Output DTO for `POST /feedback`."""

    model_config = ConfigDict(
        extra="forbid",
        json_schema_extra=cast(Any, {"example": _FEEDBACK_RESPONSE_EXAMPLE}),
    )

    feedback_id: str
    request_id: str
    accepted: bool
    domain_tag: DomainTag


class FeedbackRecord(BaseModel):
    """In-memory representation of a persisted feedback row."""

    model_config = ConfigDict(extra="forbid")

    feedback_id: str
    plan_id: str
    domain_tag: DomainTag
    corrected_field: str
    before: str
    after: str
    reason: str


class FewShotExample(BaseModel):
    """A retrieved feedback record reformulated as an Agent 3 few-shot."""

    model_config = ConfigDict(extra="forbid")

    corrected_field: str
    before: str
    after: str
    reason: str
    domain_tag: DomainTag
    relevance_score: float = Field(ge=0.0, le=1.0)
