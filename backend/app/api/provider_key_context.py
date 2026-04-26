"""Per-request resolved OpenAI/Tavily keys (headers → DB → env)."""

from __future__ import annotations

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from contextvars import ContextVar, Token
from dataclasses import dataclass

import structlog
from fastapi import HTTPException, Request

from app.config.settings import get_settings
from app.storage.provider_api_keys_repo import ProviderApiKeysRepo

_log = structlog.get_logger("app")

# HTTP header names (must match Flutter `user_api_keys_constants.dart`).
HEADER_OPENAI = "x-openai-api-key"
HEADER_TAVILY = "x-tavily-api-key"


@dataclass(frozen=True)
class ResolvedProviderKeys:
    openai: str
    tavily: str


_bundle: ContextVar[ResolvedProviderKeys | None] = ContextVar("provider_key_bundle", default=None)


def current_provider_keys() -> ResolvedProviderKeys | None:
    return _bundle.get()


def require_resolved_keys() -> ResolvedProviderKeys:
    b = _bundle.get()
    if b is None:
        raise RuntimeError("provider keys context not installed for this request")
    return b


@asynccontextmanager
async def provider_key_context(
    request: Request,
    repo: ProviderApiKeysRepo,
) -> AsyncIterator[None]:
    """Resolve keys, set context for Switching* clients, reset on exit."""

    settings = get_settings()
    h_o = (request.headers.get(HEADER_OPENAI) or "").strip()
    h_t = (request.headers.get(HEADER_TAVILY) or "").strip()
    db_o, db_t = await repo.get_keys()
    o = h_o or (db_o or "") or settings.OPENAI_API_KEY.get_secret_value()
    t = h_t or (db_t or "") or settings.TAVILY_API_KEY.get_secret_value()
    if not o or not t:
        _log.warning(
            "app.provider_keys.missing",
            has_header_openai=bool(h_o),
            has_header_tavily=bool(h_t),
            has_db_openai=bool(db_o),
            has_db_tavily=bool(db_t),
            has_env_openai=bool(settings.OPENAI_API_KEY.get_secret_value()),
            has_env_tavily=bool(settings.TAVILY_API_KEY.get_secret_value()),
        )
        raise HTTPException(
            status_code=503,
            detail=(
                "OpenAI and Tavily API keys are not configured. "
                "Set them in the app, use PUT /settings/provider-api-keys, "
                "or set OPENAI_API_KEY and TAVILY_API_KEY in the environment."
            ),
        )
    bundle = ResolvedProviderKeys(openai=o, tavily=t)
    token: Token = _bundle.set(bundle)
    try:
        yield
    finally:
        _bundle.reset(token)


async def install_provider_keys(
    request: Request,
) -> AsyncIterator[None]:
    """FastAPI dependency: activate provider key context for this request."""

    repo = ProviderApiKeysRepo(request.app.state.db_session_factory)
    async with provider_key_context(request, repo):
        yield
