"""`GET /health` — operational liveness probe."""

from __future__ import annotations

from fastapi import APIRouter

from app.schemas.responses import HealthResponse

router = APIRouter(tags=["Health"])


@router.get(
    "/health",
    response_model=HealthResponse,
    summary="Liveness probe",
    description=(
        "Returns `{\"status\":\"ok\"}` when the process is running. "
        "Use for load balancer health checks and quick smoke tests."
    ),
)
async def health() -> HealthResponse:
    """Return a static `{"status": "ok"}` body to confirm the server is up."""

    return HealthResponse(status="ok")
