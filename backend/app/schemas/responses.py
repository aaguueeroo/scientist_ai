"""HTTP response schemas exposed by the FastAPI layer."""

from __future__ import annotations

from pydantic import BaseModel


class HealthResponse(BaseModel):
    """Body of `GET /health`."""

    status: str = "ok"
