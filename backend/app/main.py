"""FastAPI app factory.

Future steps will populate the `lifespan` handler with OpenAI/Tavily
client construction and SQLite engine setup.
"""

from __future__ import annotations

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.api.health import router as health_router
from app.api.middleware import RequestContextMiddleware
from app.observability.logging import configure_logging


@asynccontextmanager
async def lifespan(_app: FastAPI) -> AsyncIterator[None]:
    """Application lifespan; M1 keeps it empty, later steps add resources."""

    configure_logging()
    yield


def create_app() -> FastAPI:
    """Build the FastAPI application."""

    app = FastAPI(title="AI Scientist backend", lifespan=lifespan)
    app.add_middleware(RequestContextMiddleware)
    app.include_router(health_router)
    return app


app = create_app()
