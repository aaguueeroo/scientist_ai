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

from app.clients.openai_client import AbstractOpenAIClient, PriceTable
from app.clients.switching_clients import (
    build_switching_openai_client,
    build_switching_tavily_client,
)
from app.clients.tavily_client import AbstractTavilyClient
from app.config.settings import Settings
from app.config.source_tiers import SourceTiersConfig
from app.storage.feedback_repo import FeedbackRepo
from app.storage.literature_review_repo import LiteratureReviewRepo
from app.storage.plans_repo import PlansRepo
from app.verification.catalog_resolver import (
    AbstractCatalogResolver,
    RealCatalogResolver,
)
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
    """Build a switching OpenAI client (per-request keys from context or env)."""

    return build_switching_openai_client(settings)


def build_tavily_client(
    settings: Settings,
    source_tiers: SourceTiersConfig,
) -> AbstractTavilyClient:
    """Build a switching Tavily client (per-request keys from context or env)."""

    return build_switching_tavily_client(settings, source_tiers)


def build_citation_resolver(source_tiers: SourceTiersConfig) -> AbstractCitationResolver:
    """Build the citation resolver shared by Agent 1 and Agent 3."""

    return RealCitationResolver(source_tiers=source_tiers)


def build_catalog_resolver(source_tiers: SourceTiersConfig) -> AbstractCatalogResolver:
    """Build the catalog resolver used by the grounding pipeline."""

    return RealCatalogResolver(source_tiers=source_tiers)


async def get_openai_client(request: Request) -> AbstractOpenAIClient:
    return cast(AbstractOpenAIClient, request.app.state.openai_client)


async def get_tavily_client(request: Request) -> AbstractTavilyClient:
    return cast(AbstractTavilyClient, request.app.state.tavily_client)


async def get_citation_resolver(request: Request) -> AbstractCitationResolver:
    return cast(AbstractCitationResolver, request.app.state.citation_resolver)


async def get_catalog_resolver(request: Request) -> AbstractCatalogResolver:
    return cast(AbstractCatalogResolver, request.app.state.catalog_resolver)


async def get_plans_repo(request: Request) -> PlansRepo:
    return cast(PlansRepo, request.app.state.plans_repo)


async def get_feedback_repo(request: Request) -> FeedbackRepo:
    return cast(FeedbackRepo, request.app.state.feedback_repo)


async def get_literature_review_repo(request: Request) -> LiteratureReviewRepo:
    return cast(LiteratureReviewRepo, request.app.state.literature_review_repo)


async def get_source_tiers(request: Request) -> SourceTiersConfig:
    return cast(SourceTiersConfig, request.app.state.source_tiers)
