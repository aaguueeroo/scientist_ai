"""Closed-set error envelope shared by every endpoint.

The closed `ErrorCode` set is non-extensible: rate-limit 429s reuse
`OPENAI_RATE_LIMITED`; unknown plan ids on `GET /plans/{id}` reuse
`VALIDATION_ERROR`. Any new error shape must reuse one of these eight
codes.
"""

from __future__ import annotations

from enum import StrEnum
from typing import Any

from pydantic import BaseModel, Field


class ErrorCode(StrEnum):
    """Closed set of API error codes (8). See `app/api/errors.py` for HTTP mapping."""

    VALIDATION_ERROR = "validation_error"
    TAVILY_UNAVAILABLE = "tavily_unavailable"
    OPENAI_UNAVAILABLE = "openai_unavailable"
    OPENAI_RATE_LIMITED = "openai_rate_limited"
    STRUCTURED_OUTPUT_INVALID = "structured_output_invalid"
    GROUNDING_FAILED_REFUSED = "grounding_failed_refused"
    COST_CEILING_EXCEEDED = "cost_ceiling_exceeded"
    INTERNAL_ERROR = "internal_error"


class ErrorResponse(BaseModel):
    """Single error envelope returned by every non-2xx response."""

    code: ErrorCode
    message: str
    details: dict[str, Any] = Field(default_factory=dict)
    request_id: str
