"""Lifespan tests for `app.main` (Step 25).

The startup handler builds the OpenAI/Tavily clients (and the citation
resolver and tier classifier) and stores them on `app.state`; the
shutdown handler calls `aclose()` on each. Tests substitute fakes via
`monkeypatch` so we never touch the real network.
"""

from __future__ import annotations

import pytest
from httpx import ASGITransport, AsyncClient

from app.api import deps as api_deps
from app.clients.openai_client import FakeOpenAIClient
from app.clients.tavily_client import FakeTavilyClient
from app.config.source_tiers import SourceTiersConfig, load_source_tiers
from app.verification.citation_resolver import FakeCitationResolver


@pytest.mark.asyncio
async def test_lifespan_closes_openai_and_tavily_clients_on_shutdown(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    fake_openai = FakeOpenAIClient()
    fake_tavily = FakeTavilyClient()
    fake_resolver = FakeCitationResolver(outcomes={})

    monkeypatch.setattr(
        api_deps,
        "build_openai_client",
        lambda settings: fake_openai,
    )
    monkeypatch.setattr(
        api_deps,
        "build_tavily_client",
        lambda settings, source_tiers: fake_tavily,
    )
    monkeypatch.setattr(
        api_deps,
        "build_citation_resolver",
        lambda source_tiers: fake_resolver,
    )

    from app.main import create_app

    app = create_app()
    async with app.router.lifespan_context(app):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.get("/health")
        assert response.status_code == 200
        assert isinstance(app.state.openai_client, FakeOpenAIClient)
        assert isinstance(app.state.tavily_client, FakeTavilyClient)
        assert isinstance(app.state.citation_resolver, FakeCitationResolver)
        assert isinstance(app.state.source_tiers, SourceTiersConfig)

    assert fake_openai.closed is True
    assert fake_tavily.closed is True


@pytest.mark.asyncio
async def test_lifespan_uses_real_source_tiers_loader(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Smoke check: source-tier config is loaded from YAML at startup."""

    fake_openai = FakeOpenAIClient()
    fake_tavily = FakeTavilyClient()
    fake_resolver = FakeCitationResolver(outcomes={})

    monkeypatch.setattr(
        api_deps,
        "build_openai_client",
        lambda settings: fake_openai,
    )
    monkeypatch.setattr(
        api_deps,
        "build_tavily_client",
        lambda settings, source_tiers: fake_tavily,
    )
    monkeypatch.setattr(
        api_deps,
        "build_citation_resolver",
        lambda source_tiers: fake_resolver,
    )

    from app.main import create_app

    app = create_app()
    async with app.router.lifespan_context(app):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            await client.get("/health")
        loaded: SourceTiersConfig = app.state.source_tiers
        canonical = load_source_tiers()
        assert loaded.tavily_include_domains() == canonical.tavily_include_domains()
