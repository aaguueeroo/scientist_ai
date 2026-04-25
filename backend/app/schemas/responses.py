"""HTTP response schemas exposed by the FastAPI layer."""

from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field


class HealthResponse(BaseModel):
    """Body of `GET /health`."""

    status: str = "ok"


class GeneratePlanResponse(BaseModel):
    """Envelope returned by `POST /generate-plan` and `GET /plans/{id}`.

    The `qc`, `plan`, and `grounding_summary` fields are typed loosely as
    placeholders here and are tightened to the concrete schemas
    (`LiteratureQCResult`, `ExperimentPlan`, `GroundingSummary`) when
    those modules land in Steps 13 and 26. Forward-declaring them via
    `TYPE_CHECKING` would require modules that do not exist yet, so the
    plan keeps the imports deferred. This is not a permanent widening:
    later steps replace `Any` with the real types.
    """

    plan_id: str | None = None
    request_id: str
    qc: Any
    plan: Any | None = None
    grounding_summary: Any
    prompt_versions: dict[str, str] = Field(default_factory=dict)
