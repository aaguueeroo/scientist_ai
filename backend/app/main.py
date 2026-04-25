"""FastAPI app factory + lifespan.

The lifespan handler builds the OpenAI/Tavily clients and the citation
resolver at startup, stores them on `app.state`, and `aclose()`s them at
shutdown. Tests substitute fakes via `monkeypatch` of the `build_*`
factory functions in `app.api.deps`.
"""

from __future__ import annotations

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.api import deps as api_deps
from app.api.errors import register_exception_handlers
from app.api.generate_plan import router as generate_plan_router
from app.api.health import router as health_router
from app.api.middleware import RequestContextMiddleware
from app.config.settings import get_settings
from app.config.source_tiers import load_source_tiers
from app.observability.logging import configure_logging


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    """Build runtime clients on startup; close them on shutdown."""

    configure_logging()
    settings = get_settings()
    source_tiers = load_source_tiers()

    openai_client = api_deps.build_openai_client(settings)
    tavily_client = api_deps.build_tavily_client(settings, source_tiers)
    citation_resolver = api_deps.build_citation_resolver(source_tiers)
    catalog_resolver = api_deps.build_catalog_resolver(source_tiers)

    app.state.openai_client = openai_client
    app.state.tavily_client = tavily_client
    app.state.citation_resolver = citation_resolver
    app.state.catalog_resolver = catalog_resolver
    app.state.source_tiers = source_tiers

    try:
        yield
    finally:
        await openai_client.aclose()
        await tavily_client.aclose()


def create_app() -> FastAPI:
    """Build the FastAPI application."""

    app = FastAPI(title="AI Scientist backend", lifespan=lifespan)
    app.add_middleware(RequestContextMiddleware)
    register_exception_handlers(app)
    app.include_router(health_router)
    app.include_router(generate_plan_router)
    return app


app = create_app()
