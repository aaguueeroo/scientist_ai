"""Tests for request-id middleware + per-request structured log line."""

from __future__ import annotations

import io
import json
import logging
from collections.abc import Iterator

import pytest
import structlog
from httpx import ASGITransport, AsyncClient

from app.main import create_app
from app.observability.logging import configure_logging


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
