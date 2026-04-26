"""FastAPI app factory + lifespan.

The lifespan handler builds the OpenAI/Tavily clients and the citation
resolver at startup, stores them on `app.state`, and `aclose()`s them at
shutdown. Tests substitute fakes via `monkeypatch` of the `build_*`
factory functions in `app.api.deps`.
"""

from __future__ import annotations

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

import structlog
from fastapi import FastAPI

from app.api import deps as api_deps
from app.api.debug_tavily import router as debug_tavily_router
from app.api.openapi_extra import enrich_openapi_schema
from app.api.errors import register_exception_handlers
from app.api.conversations import router as conversations_router
from app.api.experiment_plan import router as experiment_plan_router
from app.api.feedback import router as feedback_router
from app.api.health import router as health_router
from app.api.literature_review import router as literature_review_router
from app.api.middleware import RateLimitMiddleware, RequestContextMiddleware
from app.api.openapi_meta import API_DESCRIPTION, OPENAPI_TAGS
from app.api.plans import router as plans_router
from app.config.settings import get_settings
from app.config.source_tiers import load_source_tiers
from app.observability.logging import configure_logging
from app.storage import db as storage_db
from app.storage.feedback_repo import FeedbackRepo
from app.storage.literature_review_repo import LiteratureReviewRepo
from app.storage.plans_repo import PlansRepo


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    """Build runtime clients on startup; close them on shutdown."""

    settings = get_settings()
    configure_logging(log_level=settings.logging_level())
    _log = structlog.get_logger("app")
    _log.info(
        "app.startup.begin",
        log_level=settings.LOG_LEVEL,
        database_kind="sqlite" if "sqlite" in settings.DATABASE_URL else "other",
    )
    source_tiers = load_source_tiers()

    openai_client = api_deps.build_openai_client(settings)
    tavily_client = api_deps.build_tavily_client(settings, source_tiers)
    citation_resolver = api_deps.build_citation_resolver(source_tiers)
    catalog_resolver = api_deps.build_catalog_resolver(source_tiers)
    db_engine = storage_db.create_engine(settings)
    await storage_db.create_all(db_engine)
    db_session_factory = storage_db.async_session(db_engine)
    plans_repo = PlansRepo(db_session_factory)
    feedback_repo = FeedbackRepo(db_session_factory)
    literature_review_repo = LiteratureReviewRepo(db_session_factory)

    app.state.openai_client = openai_client
    app.state.tavily_client = tavily_client
    app.state.citation_resolver = citation_resolver
    app.state.catalog_resolver = catalog_resolver
    app.state.source_tiers = source_tiers
    app.state.db_engine = db_engine
    app.state.db_session_factory = db_session_factory
    app.state.plans_repo = plans_repo
    app.state.feedback_repo = feedback_repo
    app.state.literature_review_repo = literature_review_repo

    _log.info("app.startup.ready")
    try:
        yield
    finally:
        _log.info("app.shutdown.begin")
        await openai_client.aclose()
        await tavily_client.aclose()
        await db_engine.dispose()
        _log.info("app.shutdown.complete")


def create_app() -> FastAPI:
    """Build the FastAPI application.

    `get_settings()` is called lazily — only when constructing the rate
    limiter — so that test modules that import `app.main` without having
    `OPENAI_API_KEY`/`TAVILY_API_KEY` populated yet still load.
    """

    app = FastAPI(
        title="AI Scientist API",
        description=API_DESCRIPTION,
        version="0.1.0",
        lifespan=lifespan,
        openapi_tags=OPENAPI_TAGS,
        docs_url="/docs",
        redoc_url="/redoc",
        openapi_url="/openapi.json",
    )
    # Order matters: RequestContextMiddleware is added last so it's the
    # outermost middleware (it must always observe the response, including
    # 429s emitted by the rate limiter).
    app.add_middleware(
        RateLimitMiddleware,
        rate_limit_per_min_factory=lambda: get_settings().RATE_LIMIT_PER_MIN,
    )
    app.add_middleware(RequestContextMiddleware)
    register_exception_handlers(app)
    app.include_router(health_router)
    app.include_router(debug_tavily_router)
    app.include_router(literature_review_router)
    app.include_router(experiment_plan_router)
    app.include_router(conversations_router)
    app.include_router(plans_router)
    app.include_router(feedback_router)

    def _custom_openapi() -> dict[str, object]:
        if app.openapi_schema:  # pragma: no cover - cache
            return app.openapi_schema
        from fastapi.openapi.utils import get_openapi  # local import, matches FastAPI

        s = get_openapi(
            title=app.title,
            version=app.version,
            openapi_version=app.openapi_version,
            description=app.description,
            routes=app.routes,
            tags=app.openapi_tags,
        )
        app.openapi_schema = enrich_openapi_schema(s)
        return app.openapi_schema

    app.openapi = _custom_openapi
    return app


app = create_app()
