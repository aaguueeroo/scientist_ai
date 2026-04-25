"""HTTP middleware: request id, structured log line, request-scoped state.

The middleware:
1. Generates (or accepts) a `request_id` per request and binds it into
   `structlog.contextvars`.
2. Maintains a `RequestContext` exposed via `request.state` so downstream
   code can accumulate `total_cost_usd`, `verified_count`, `tier_0_drops`
   without bypassing this middleware.
3. Emits exactly one `event="http.request.complete"` JSON log line per
   request (per `docs/research.md` §13).
"""

from __future__ import annotations

import time
import uuid
from collections.abc import Awaitable, Callable
from dataclasses import dataclass

import structlog
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

from app.observability.logging import bind_request, clear_request

REQUEST_ID_HEADER = "x-request-id"


@dataclass
class RequestContext:
    """Per-request scratch space mutated by orchestrator/agents/middleware."""

    request_id: str
    total_cost_usd: float = 0.0
    verified_count: int = 0
    tier_0_drops: int = 0
    agent_calls: int = 0


def _new_request_id() -> str:
    return uuid.uuid4().hex


class RequestContextMiddleware(BaseHTTPMiddleware):
    """Bind a request id, expose RequestContext, emit one structured log line."""

    async def dispatch(
        self,
        request: Request,
        call_next: Callable[[Request], Awaitable[Response]],
    ) -> Response:
        request_id = request.headers.get(REQUEST_ID_HEADER) or _new_request_id()
        ctx = RequestContext(request_id=request_id)
        request.state.request_context = ctx
        bind_request(request_id)

        logger = structlog.get_logger("http")
        start = time.perf_counter()
        try:
            response = await call_next(request)
        finally:
            latency_ms = int((time.perf_counter() - start) * 1000)

        response.headers[REQUEST_ID_HEADER] = request_id
        logger.info(
            "http.request.complete",
            method=request.method,
            path=request.url.path,
            status=response.status_code,
            latency_ms=latency_ms,
            request_id=request_id,
            agent_calls=ctx.agent_calls,
            total_cost_usd=ctx.total_cost_usd,
            verified_count=ctx.verified_count,
            tier_0_drops=ctx.tier_0_drops,
        )
        clear_request()
        return response
