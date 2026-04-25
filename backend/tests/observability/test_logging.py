"""Tests for `app/observability/logging.py` — structlog JSON contract."""

from __future__ import annotations

import io
import json
import logging
from collections.abc import Iterator

import pytest
import structlog

from app.observability.logging import (
    AGENT_LOG_REQUIRED_KEYS,
    agent_call_logger,
    bind_request,
    configure_logging,
)


@pytest.fixture(autouse=True)
def _reset_structlog() -> Iterator[None]:
    """Each test starts from a known structlog context."""

    structlog.contextvars.clear_contextvars()
    yield
    structlog.contextvars.clear_contextvars()


def _capture_buffer() -> io.StringIO:
    buffer = io.StringIO()
    handler = logging.StreamHandler(buffer)
    handler.setFormatter(logging.Formatter("%(message)s"))
    root = logging.getLogger()
    for existing in list(root.handlers):
        root.removeHandler(existing)
    root.addHandler(handler)
    root.setLevel(logging.INFO)
    configure_logging()
    return buffer


def test_logging_emits_json_parseable_line() -> None:
    buffer = _capture_buffer()
    logger = structlog.get_logger("test")
    logger.info("hello", foo="bar")
    line = buffer.getvalue().strip().splitlines()[-1]
    parsed = json.loads(line)
    assert parsed["event"] == "hello"
    assert parsed["foo"] == "bar"


def test_logging_request_id_propagates_through_contextvars() -> None:
    buffer = _capture_buffer()
    bind_request("01HW4K3M9N1Q7VS6E2YBZ5XJDA")
    structlog.get_logger("test").info("payload")
    line = buffer.getvalue().strip().splitlines()[-1]
    parsed = json.loads(line)
    assert parsed["request_id"] == "01HW4K3M9N1Q7VS6E2YBZ5XJDA"


def test_agent_call_logger_emits_required_keys() -> None:
    buffer = _capture_buffer()
    bind_request("01HW4K3M9N1Q7VS6E2YBZ5XJDA")
    logger = agent_call_logger("literature_qc")
    logger.info(
        "agent.call.complete",
        model="gpt-4.1-mini",
        prompt_hash="9a4f2c1e8b03",
        prompt_tokens=1245,
        completion_tokens=312,
        latency_ms=1820,
        verified_count=3,
        tier_0_drops=0,
    )
    line = buffer.getvalue().strip().splitlines()[-1]
    parsed = json.loads(line)
    assert parsed["event"] == "agent.call.complete"
    for key in AGENT_LOG_REQUIRED_KEYS:
        assert key in parsed, f"missing key {key} in {parsed}"
