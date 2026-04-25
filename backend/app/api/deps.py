"""FastAPI dependency providers + factory functions for runtime clients.

Construction lives here so:

- `app.main.lifespan` calls the `build_*` factory functions at startup
  and stores the result on `app.state`. Tests can monkeypatch the
  factories to substitute fakes.
- The `get_*` providers are wired into routes via `Depends(...)`. Each
  pulls the matching object off `app.state`. Tests can also override
  these directly via `app.dependency_overrides` for finer-grained
  swapping (per-test) without touching the lifespan.
"""

from __future__ import annotations

from typing import cast

from fastapi import Request

from app.clients.openai_client import (
    AbstractOpenAIClient,
    CostTracker,
    PriceTable,
    RealOpenAIClient,
)
from app.clients.tavily_client import AbstractTavilyClient, RealTavilyClient
from app.config.settings import Settings
from app.config.source_tiers import SourceTiersConfig
from app.verification.citation_resolver import (
    AbstractCitationResolver,
    RealCitationResolver,
)


def build_price_table(settings: Settings) -> PriceTable:
    """Construct the per-token price table from settings."""

    return PriceTable(
        input_per_token={
            "gpt-4.1": settings.OPENAI_PRICE_INPUT_PER_TOKEN_GPT_4_1,
            "gpt-4.1-mini": settings.OPENAI_PRICE_INPUT_PER_TOKEN_GPT_4_1_MINI,
        },
        output_per_token={
            "gpt-4.1": settings.OPENAI_PRICE_OUTPUT_PER_TOKEN_GPT_4_1,
            "gpt-4.1-mini": settings.OPENAI_PRICE_OUTPUT_PER_TOKEN_GPT_4_1_MINI,
        },
    )


def build_openai_client(settings: Settings) -> AbstractOpenAIClient:
    """Build a `RealOpenAIClient` with a per-process cost tracker.

    The cost tracker enforces `MAX_REQUEST_USD` from settings; in v1 the
    tracker is process-scoped (later steps may move it per-request).
    """

    cost_tracker = CostTracker(
        ceiling_usd=settings.MAX_REQUEST_USD,
        prices=build_price_table(settings),
    )
    return RealOpenAIClient(
        api_key=settings.OPENAI_API_KEY.get_secret_value(),
        cost_tracker=cost_tracker,
    )


def build_tavily_client(
    settings: Settings,
    source_tiers: SourceTiersConfig,
) -> AbstractTavilyClient:
    """Build a `RealTavilyClient` with the tier-derived domain allowlist."""

    return RealTavilyClient(
        api_key=settings.TAVILY_API_KEY.get_secret_value(),
        source_tiers=source_tiers,
    )


def build_citation_resolver(source_tiers: SourceTiersConfig) -> AbstractCitationResolver:
    """Build the citation resolver shared by Agent 1 and Agent 3."""

    return RealCitationResolver(source_tiers=source_tiers)


async def get_openai_client(request: Request) -> AbstractOpenAIClient:
    return cast(AbstractOpenAIClient, request.app.state.openai_client)


async def get_tavily_client(request: Request) -> AbstractTavilyClient:
    return cast(AbstractTavilyClient, request.app.state.tavily_client)


async def get_citation_resolver(request: Request) -> AbstractCitationResolver:
    return cast(AbstractCitationResolver, request.app.state.citation_resolver)


async def get_source_tiers(request: Request) -> SourceTiersConfig:
    return cast(SourceTiersConfig, request.app.state.source_tiers)
