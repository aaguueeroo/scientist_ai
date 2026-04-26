"""Tests for request-id middleware + per-request structured log line."""

from __future__ import annotations

import io
import json
import logging
from collections.abc import Iterator

import pytest
import structlog
from fastapi import FastAPI as _FastAPI
from httpx import ASGITransport, AsyncClient

from app.api.errors import register_exception_handlers
from app.api.middleware import RateLimitMiddleware, RequestContextMiddleware
from app.main import create_app
from app.observability.logging import configure_logging
from app.schemas.errors import ErrorCode


@pytest.fixture(autouse=True)
def _attach_capturing_log_handler() -> Iterator[io.StringIO]:
    structlog.contextvars.clear_contextvars()
    buffer = io.StringIO()
    handler = logging.StreamHandler(buffer)
    handler.setFormatter(logging.Formatter("%(message)s"))
    root = logging.getLogger()
    previous_handlers = list(root.handlers)
    for existing in previous_handlers:
        root.removeHandler(existing)
    root.addHandler(handler)
    previous_level = root.level
    root.setLevel(logging.INFO)
    configure_logging()
    yield buffer
    structlog.contextvars.clear_contextvars()
    root.removeHandler(handler)
    for existing in previous_handlers:
        root.addHandler(existing)
    root.setLevel(previous_level)


def _http_log_line(buffer: io.StringIO) -> dict[str, object]:
    for raw in buffer.getvalue().strip().splitlines():
        try:
            record: dict[str, object] = json.loads(raw)
        except json.JSONDecodeError:
            continue
        if record.get("event") == "http.request.complete":
            return record
    raise AssertionError("no http.request.complete log line emitted")


@pytest.mark.asyncio
async def test_middleware_assigns_request_id_when_missing(
    _attach_capturing_log_handler: io.StringIO,
) -> None:
    app = create_app()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/health")
    assert response.headers.get("x-request-id"), "X-Request-ID must always be set"


@pytest.mark.asyncio
async def test_middleware_propagates_existing_request_id_header(
    _attach_capturing_log_handler: io.StringIO,
) -> None:
    app = create_app()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get(
            "/health",
            headers={"X-Request-ID": "client-supplied-id"},
        )
    assert response.headers["x-request-id"] == "client-supplied-id"


@pytest.mark.asyncio
async def test_middleware_emits_one_http_log_per_request_with_required_keys(
    _attach_capturing_log_handler: io.StringIO,
) -> None:
    app = create_app()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        await client.get("/health")
    record = _http_log_line(_attach_capturing_log_handler)
    for key in ("method", "path", "status", "latency_ms", "request_id"):
        assert key in record, f"missing {key} in http log: {record}"
    assert record["method"] == "GET"
    assert record["path"] == "/health"
    assert record["status"] == 200


@pytest.mark.asyncio
async def test_middleware_response_carries_x_request_id_header(
    _attach_capturing_log_handler: io.StringIO,
) -> None:
    app = create_app()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get(
            "/health",
            headers={"X-Request-ID": "abc-123"},
        )
    assert response.headers.get("x-request-id") == "abc-123"


# ---------------------------------------------------------------------------
# Step 46 — Rate-limit middleware
# ---------------------------------------------------------------------------


def _build_rate_limited_app(*, limit_per_min: int) -> _FastAPI:
    """Minimal app that mirrors the production middleware stack.

    We avoid `create_app()` here because that wires the heavy lifespan
    (OpenAI/Tavily/SQLite). For middleware behaviour all we need is the
    rate-limit middleware mounted before a couple of trivial routes.
    """

    app = _FastAPI()
    app.add_middleware(RateLimitMiddleware, rate_limit_per_min=limit_per_min)
    app.add_middleware(RequestContextMiddleware)
    register_exception_handlers(app)

    @app.get("/health")
    async def _health() -> dict[str, str]:
        return {"status": "ok"}

    @app.post("/literature-review")
    async def _literature_review() -> dict[str, str]:
        return {"ok": "true"}

    @app.post("/experiment-plan")
    async def _experiment_plan() -> dict[str, str]:
        return {"ok": "true"}

    @app.post("/feedback")
    async def _feedback() -> dict[str, str]:
        return {"ok": "true"}

    return app


@pytest.mark.asyncio
async def test_rate_limit_allows_within_quota(
    _attach_capturing_log_handler: io.StringIO,
) -> None:
    app = _build_rate_limited_app(limit_per_min=5)
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        for _ in range(5):
            response = await client.post(
                "/experiment-plan",
                json={"query": "x" * 30, "literature_review_id": "lr-mw"},
                headers={"X-Forwarded-For": "10.0.0.1"},
            )
            assert response.status_code == 200, response.text


@pytest.mark.asyncio
async def test_rate_limit_breach_returns_429_with_error_response(
    _attach_capturing_log_handler: io.StringIO,
) -> None:
    app = _build_rate_limited_app(limit_per_min=2)
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        for _ in range(2):
            ok_response = await client.post(
                "/experiment-plan",
                json={"query": "x" * 30, "literature_review_id": "lr-mw2"},
                headers={"X-Forwarded-For": "10.0.0.2"},
            )
            assert ok_response.status_code == 200

        breach = await client.post(
            "/experiment-plan",
            json={"query": "x" * 30, "literature_review_id": "lr-mw2"},
            headers={"X-Forwarded-For": "10.0.0.2"},
        )

    assert breach.status_code == 429, breach.text
    body = breach.json()
    assert body["code"] == ErrorCode.OPENAI_RATE_LIMITED.value
    assert "rate limit" in body["message"].lower()
    assert body["request_id"]


@pytest.mark.asyncio
async def test_rate_limit_does_not_apply_to_health_endpoint(
    _attach_capturing_log_handler: io.StringIO,
) -> None:
    app = _build_rate_limited_app(limit_per_min=1)
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        for _ in range(10):
            response = await client.get(
                "/health",
                headers={"X-Forwarded-For": "10.0.0.3"},
            )
            assert response.status_code == 200


@pytest.mark.asyncio
async def test_rate_limit_response_includes_retry_after_in_details(
    _attach_capturing_log_handler: io.StringIO,
) -> None:
    app = _build_rate_limited_app(limit_per_min=1)
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        ok = await client.post(
            "/feedback",
            json={"corrected_field": "x"},
            headers={"X-Forwarded-For": "10.0.0.4"},
        )
        assert ok.status_code == 200

        breach = await client.post(
            "/feedback",
            json={"corrected_field": "x"},
            headers={"X-Forwarded-For": "10.0.0.4"},
        )

    assert breach.status_code == 429
    body = breach.json()
    details = body.get("details", {})
    assert "retry_after_s" in details, f"missing retry_after_s in details: {details}"
    retry_after = details["retry_after_s"]
    assert isinstance(retry_after, int) and retry_after >= 1, (
        f"retry_after_s must be a positive int seconds value, got {retry_after!r}"
    )
