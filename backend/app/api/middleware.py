"""HTTP middleware: request id, structured log line, request-scoped state.

The middleware:
1. Generates (or accepts) a `request_id` per request and binds it into
   `structlog.contextvars`.
2. Maintains a `RequestContext` exposed via `request.state` so downstream
   code can accumulate `total_cost_usd`, `verified_count`, `tier_0_drops`
   without bypassing this middleware.
3. Emits exactly one `event="http.request.complete"` JSON log line per
   request (per `docs/research.md` §13).
4. Enforces a per-IP token-bucket rate limit (Step 46) on
   `POST /literature-review`, `POST /experiment-plan`, and `POST /feedback`. On
   breach the middleware returns a closed-set
   `ErrorCode.OPENAI_RATE_LIMITED` `ErrorResponse` (HTTP 429) with the
   recommended `retry_after_s` in `details`.
"""

from __future__ import annotations

import asyncio
import time
import uuid
from collections.abc import Awaitable, Callable
from dataclasses import dataclass, field
from math import ceil

import structlog
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse, Response
from starlette.types import ASGIApp

from app.observability.logging import bind_request, clear_request
from app.schemas.errors import ErrorCode, ErrorResponse

REQUEST_ID_HEADER = "x-request-id"
_RATE_LIMITED_PATHS = frozenset({"/literature-review", "/experiment-plan", "/feedback"})


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
        path_qs = f"{request.url.path}"
        if request.url.query:
            path_qs = f"{path_qs}?{request.url.query[:2000]}"
        logger.debug(
            "http.request.begin",
            method=request.method,
            path=request.url.path,
            path_with_query=path_qs,
            content_type=(request.headers.get("content-type") or ""),
            client_host=request.client.host if request.client else None,
            request_id=request_id,
        )
        try:
            response = await call_next(request)
        finally:
            latency_ms = int((time.perf_counter() - start) * 1000)

        response.headers[REQUEST_ID_HEADER] = request_id
        logger.debug(
            "http.request.response_start",
            method=request.method,
            path=request.url.path,
            status=response.status_code,
            latency_ms=latency_ms,
            media_type=getattr(response, "media_type", None) or "",
            request_id=request_id,
        )
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


@dataclass
class _Bucket:
    """Per-IP token-bucket state."""

    tokens: float
    last_refill: float = field(default_factory=time.monotonic)


class RateLimitMiddleware(BaseHTTPMiddleware):
    """Per-IP token bucket gating `/literature-review`, `/experiment-plan`, and `/feedback`.

    The bucket capacity equals `rate_limit_per_min`; tokens refill at
    `rate_limit_per_min / 60` per second. A request consumes one token;
    if the bucket is empty the middleware short-circuits with HTTP 429
    + `ErrorCode.OPENAI_RATE_LIMITED` (rate-limit 429s reuse the
    existing OpenAI rate-limit code per the closed `ErrorCode` enum).
    """

    def __init__(
        self,
        app: ASGIApp,
        *,
        rate_limit_per_min: int | None = None,
        rate_limit_per_min_factory: Callable[[], int] | None = None,
    ) -> None:
        super().__init__(app)
        if (rate_limit_per_min is None) == (rate_limit_per_min_factory is None):
            raise ValueError(
                "exactly one of rate_limit_per_min or rate_limit_per_min_factory required"
            )
        self._explicit_limit = rate_limit_per_min
        self._limit_factory = rate_limit_per_min_factory
        self._capacity: float | None = None
        self._refill_per_second: float | None = None
        self._buckets: dict[str, _Bucket] = {}
        self._lock = asyncio.Lock()

    def _ensure_limits_resolved(self) -> None:
        if self._capacity is not None:
            return
        if self._explicit_limit is not None:
            limit = self._explicit_limit
        else:
            assert self._limit_factory is not None
            limit = self._limit_factory()
        if limit < 1:
            raise ValueError("rate_limit_per_min must be >= 1")
        self._capacity = float(limit)
        self._refill_per_second = limit / 60.0

    async def dispatch(
        self,
        request: Request,
        call_next: Callable[[Request], Awaitable[Response]],
    ) -> Response:
        if request.url.path not in _RATE_LIMITED_PATHS:
            return await call_next(request)

        client_ip = self._client_ip(request)
        allowed, retry_after_s = await self._consume(client_ip)
        if allowed:
            return await call_next(request)

        request_id = request.headers.get(REQUEST_ID_HEADER) or _new_request_id()
        structlog.get_logger("http").warning(
            "http.rate_limited",
            method=request.method,
            path=request.url.path,
            client_ip=client_ip,
            retry_after_s=retry_after_s,
            request_id=request_id,
        )
        body = ErrorResponse(
            code=ErrorCode.OPENAI_RATE_LIMITED,
            message="rate limit exceeded; try again shortly",
            details={"retry_after_s": retry_after_s},
            request_id=request_id,
        )
        response = JSONResponse(status_code=429, content=body.model_dump())
        response.headers[REQUEST_ID_HEADER] = request_id
        response.headers["retry-after"] = str(retry_after_s)
        return response

    @staticmethod
    def _client_ip(request: Request) -> str:
        forwarded = request.headers.get("x-forwarded-for")
        if forwarded:
            return forwarded.split(",")[0].strip()
        if request.client is not None:
            return request.client.host
        return "unknown"

    async def _consume(self, client_ip: str) -> tuple[bool, int]:
        async with self._lock:
            self._ensure_limits_resolved()
            assert self._capacity is not None
            assert self._refill_per_second is not None
            now = time.monotonic()
            bucket = self._buckets.get(client_ip)
            if bucket is None:
                bucket = _Bucket(tokens=self._capacity, last_refill=now)
                self._buckets[client_ip] = bucket
            else:
                elapsed = max(0.0, now - bucket.last_refill)
                bucket.tokens = min(
                    self._capacity, bucket.tokens + elapsed * self._refill_per_second
                )
                bucket.last_refill = now

            if bucket.tokens >= 1.0:
                bucket.tokens -= 1.0
                return True, 0

            deficit = 1.0 - bucket.tokens
            seconds_to_recover = deficit / self._refill_per_second
            return False, max(1, ceil(seconds_to_recover))
