"""Tests for `GET /debug/tavily` (Tavily connectivity probe)."""

from __future__ import annotations

# mypy: disable-error-code="arg-type"
from collections.abc import AsyncIterator

import pytest
import pytest_asyncio
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import create_async_engine

from app.api import deps as api_deps
from app.clients.openai_client import FakeOpenAIClient
from app.clients.tavily_client import FakeTavilyClient, TavilyHit, TavilySearchResult
from app.storage import db as storage_db
from app.verification.catalog_resolver import FakeCatalogResolver
from app.verification.citation_resolver import FakeCitationResolver

_NATURE = "https://www.nature.com/articles/nature12345"


def _patch_in_memory_storage(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        storage_db,
        "create_engine",
        lambda settings: create_async_engine("sqlite+aiosqlite:///:memory:", future=True),
    )


@pytest_asyncio.fixture
async def debug_tavily_app(
    monkeypatch: pytest.MonkeyPatch,
) -> AsyncIterator[FastAPI]:
    from app.main import create_app

    tavily = FakeTavilyClient(
        responses=[
            TavilySearchResult(
                query="probe",
                results=[
                    TavilyHit(
                        url=_NATURE,
                        title="Example",
                        snippet="...",
                        score=0.9,
                    )
                ],
            )
        ]
    )
    monkeypatch.setattr(api_deps, "build_openai_client", lambda settings: FakeOpenAIClient())
    monkeypatch.setattr(api_deps, "build_tavily_client", lambda settings, source_tiers: tavily)
    monkeypatch.setattr(
        api_deps,
        "build_citation_resolver",
        lambda source_tiers: FakeCitationResolver(outcomes={}),
    )
    monkeypatch.setattr(
        api_deps,
        "build_catalog_resolver",
        lambda source_tiers: FakeCatalogResolver(outcomes={}),
    )
    _patch_in_memory_storage(monkeypatch)

    app = create_app()
    async with app.router.lifespan_context(app):
        yield app


@pytest.mark.asyncio
async def test_debug_tavily_returns_raw_shaped_json(debug_tavily_app: FastAPI) -> None:
    transport = ASGITransport(app=debug_tavily_app, raise_app_exceptions=False)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        r = await client.get("/debug/tavily", params={"q": "crispr review"})
    assert r.status_code == 200
    body = r.json()
    assert body["query"] == "probe"
    assert len(body["results"]) == 1
    assert str(body["results"][0]["url"]).startswith("https://")


@pytest.mark.asyncio
async def test_debug_tavily_research_mode_returns_research_shaped_json(
    debug_tavily_app: FastAPI,
) -> None:
    transport = ASGITransport(app=debug_tavily_app, raise_app_exceptions=False)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        r = await client.get(
            "/debug/tavily",
            params={"q": "crispr review", "mode": "research", "tavily_research_model": "mini"},
        )
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "completed"
    assert body["model"] == "mini"
    assert "sources" in body
