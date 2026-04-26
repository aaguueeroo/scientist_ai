"""Feedback schemas (Step 39).

These types describe the contract for `POST /feedback`, the persistence
record the feedback repo stores, and the few-shot examples Agent 2 hands to
Agent 3. The role string is loaded from disk; user content (the feedback
text) is never concatenated into a system prompt - it flows through these
typed shapes only.
"""

from __future__ import annotations

from enum import StrEnum
from typing import Any, Literal, cast

from pydantic import BaseModel, ConfigDict, Field, model_validator


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

FEW_SHOT_PLAN_REVIEW_FIELD_MARKER = "__plan_review__"
"""Value stored in `FeedbackRow.corrected_field` for plan-review rows (not few-shots)."""

_FEEDBACK_RESPONSE_EXAMPLE: dict[str, str | bool] = {
    "feedback_id": "fb-6d7c8b9a0e1f2d3c4b5a68790fedcba1",
    "request_id": "0f1e2d3c4b5a69788796a5b4c3d2e1f0",
    "accepted": True,
    "domain_tag": "cell-biology-cryopreservation",
}


class FeedbackRequest(BaseModel):
    """Legacy few-shot DTO: field correction for Agent 2 retrieval (unchanged)."""

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


class PlanReviewEventIn(BaseModel):
    """Mobile `Review` body (correction, comment, or section feedback) for `POST /feedback`."""

    model_config = ConfigDict(extra="forbid")

    plan_id: str | None = Field(
        default=None,
        max_length=80,
        description="Ties the review to a persisted plan row. Inferred from `original_plan` if omitted.",
    )
    id: str = Field(min_length=1, max_length=200)
    created_at: str = Field(min_length=1, max_length=64)
    conversation_id: str = Field(max_length=4000)
    query: str = Field(max_length=4000)
    original_plan: dict[str, Any]
    kind: Literal["correction", "comment", "feedback"]
    payload: dict[str, Any]

    @model_validator(mode="after")
    def fill_plan_id(self) -> PlanReviewEventIn:
        if self.plan_id is not None and self.plan_id.strip():
            return self.model_copy(update={"plan_id": self.plan_id.strip()})
        op = self.original_plan
        pid: str | None = None
        if isinstance(op, dict):
            raw = op.get("plan_id")
            if isinstance(raw, str) and raw.strip():
                pid = raw.strip()
        if pid is not None:
            return self.model_copy(update={"plan_id": pid})
        return self.model_copy(update={"plan_id": "unscoped"})


def looks_like_plan_review_envelope(data: object) -> bool:
    if not isinstance(data, dict):
        return False
    return (
        data.get("kind") in ("correction", "comment", "feedback")
        and "original_plan" in data
    )


def parse_post_feedback_json(data: Any) -> FeedbackRequest | PlanReviewEventIn:
    """Discriminate legacy few-shot vs plan-review (A1) on the same `POST /feedback` path."""

    if not isinstance(data, dict):
        msg = "JSON body must be an object"
        raise ValueError(msg)
    if looks_like_plan_review_envelope(data):
        return PlanReviewEventIn.model_validate(data)
    return FeedbackRequest.model_validate(data)


class FeedbackResponse(BaseModel):
    """Output DTO for `POST /feedback`."""

    model_config = ConfigDict(
        extra="forbid",
        json_schema_extra=cast(Any, {"example": _FEEDBACK_RESPONSE_EXAMPLE}),
    )

    feedback_id: str
    request_id: str
    accepted: bool
    domain_tag: DomainTag | None = None
    """Set for legacy few-shot; omitted / null for plan-review events."""
    review: dict[str, Any] | None = None
    """Echo of the stored plan review (wire `Review`); null for legacy few-shot."""


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
