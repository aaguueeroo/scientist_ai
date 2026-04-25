"""Input DTO for `POST /generate-plan`."""

from __future__ import annotations

from pydantic import BaseModel, Field


class GeneratePlanRequest(BaseModel):
    """User-submitted hypothesis."""

    hypothesis: str = Field(min_length=10, max_length=2000)
