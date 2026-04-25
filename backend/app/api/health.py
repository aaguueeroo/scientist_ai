"""`GET /health` — operational liveness probe."""

from __future__ import annotations

from fastapi import APIRouter

from app.schemas.responses import HealthResponse

router = APIRouter()


@router.get("/health", response_model=HealthResponse)
async def health() -> HealthResponse:
    """Return a static `{"status": "ok"}` body to confirm the server is up."""

    return HealthResponse(status="ok")
