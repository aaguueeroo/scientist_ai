"""Structured logging configuration.

Per `docs/research.md` §13, every runtime-agent call emits exactly one
JSON line via `structlog`'s `JSONRenderer`. The keys required on every
agent line (and asserted by tests) live in `AGENT_LOG_REQUIRED_KEYS`.
"""

from __future__ import annotations

import logging
from typing import Any, Final

import structlog
from structlog.contextvars import bind_contextvars, clear_contextvars

AGENT_LOG_REQUIRED_KEYS: Final = (
    "agent",
    "model",
    "prompt_hash",
    "prompt_tokens",
    "completion_tokens",
    "latency_ms",
    "verified_count",
    "tier_0_drops",
    "request_id",
)


def _set_stdlib_log_levels(root_level: int) -> None:
    """Point uvicorn / FastAPI loggers at the same level; keep third-party I/O at INFO."""

    root = logging.getLogger()
    root.setLevel(root_level)
    for name in ("uvicorn", "uvicorn.error", "uvicorn.access", "fastapi", "app"):
        logging.getLogger(name).setLevel(root_level)
    for name in ("httpx", "httpcore", "h11", "openai", "tavily", "tavily_async"):
        logging.getLogger(name).setLevel(logging.INFO)


def configure_logging(*, log_level: int = logging.INFO) -> None:
    """Configure structlog + the stdlib logger to emit single-line JSON.

    ``log_level`` is a ``stdlib`` int (e.g. ``logging.DEBUG``). Set **LOG_LEVEL=DEBUG** in
    ``.env`` to see:

    * ``http.request.begin`` / ``http.request.response_start`` (path, status, **latency to first byte**; for SSE, this is *not* the full stream)
    * ``app.literature_review.*`` / ``app.experiment_plan.*`` / ``pipeline.*.step_ms`` (task timings and I/O summaries)
    * Third-party loggers (``httpx``, ``openai``, …) stay at **INFO** to avoid request-body noise unless you change ``_set_stdlib_log_levels`` below.
    """

    _set_stdlib_log_levels(log_level)
    structlog.configure(
        processors=[
            structlog.contextvars.merge_contextvars,
            structlog.stdlib.add_log_level,
            structlog.processors.TimeStamper(fmt="iso", utc=True),
            structlog.processors.format_exc_info,
            structlog.processors.JSONRenderer(),
        ],
        wrapper_class=structlog.make_filtering_bound_logger(log_level),
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=False,
    )


def bind_request(request_id: str) -> None:
    """Bind `request_id` into structlog's contextvars (one per request)."""

    bind_contextvars(request_id=request_id)


def clear_request() -> None:
    """Drop all bound contextvars; called at request end."""

    clear_contextvars()


def agent_call_logger(agent_name: str) -> structlog.stdlib.BoundLogger:
    """Return a logger pre-bound to `agent=<agent_name>`."""

    logger = structlog.get_logger("agent").bind(agent=agent_name)
    return logger  # type: ignore[no-any-return]  # reason: structlog's type annotation


def emit_agent_call_complete(
    agent: str,
    *,
    model: str,
    prompt_hash: str,
    prompt_tokens: int,
    completion_tokens: int,
    latency_ms: int,
    verified_count: int,
    tier_0_drops: int,
    **extra: Any,
) -> None:
    """Emit a single `event="agent.call.complete"` line with the contract keys."""

    logger = agent_call_logger(agent)
    logger.info(
        "agent.call.complete",
        model=model,
        prompt_hash=prompt_hash,
        prompt_tokens=prompt_tokens,
        completion_tokens=completion_tokens,
        latency_ms=latency_ms,
        verified_count=verified_count,
        tier_0_drops=tier_0_drops,
        **extra,
    )
