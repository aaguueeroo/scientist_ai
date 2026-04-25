"""Tests for the Tavily client interface + fake (Step 18)."""

from __future__ import annotations

from collections.abc import Iterator
from unittest.mock import AsyncMock

import pytest

from app.api.errors import TavilyUnavailable
from app.clients.tavily_client import (
    FakeTavilyClient,
    RealTavilyClient,
    TavilyHit,
    TavilySearchResult,
)
from app.config.source_tiers import load_source_tiers


@pytest.mark.asyncio
async def test_fake_tavily_client_returns_canned_results() -> None:
    canned = TavilySearchResult(
        query="trehalose cryopreservation",
        results=[
            TavilyHit(
                url="https://www.nature.com/articles/abc",
                title="Trehalose protects cell membranes",
                snippet="Trehalose preserves cell viability...",
                score=0.93,
            )
        ],
    )
    fake = FakeTavilyClient(responses=[canned])
    result = await fake.search(
        query="trehalose cryopreservation",
        include_domains=["nature.com", "arxiv.org"],
        depth="advanced",
        max_results=5,
    )
    assert result.results[0].title.startswith("Trehalose")


@pytest.mark.asyncio
async def test_tavily_client_rejects_empty_include_domains() -> None:
    fake = FakeTavilyClient(
        responses=[TavilySearchResult(query="x", results=[])],
    )
    with pytest.raises(ValueError):
        await fake.search(
            query="x",
            include_domains=[],
            depth="advanced",
            max_results=5,
        )


@pytest.mark.asyncio
async def test_tavily_client_records_call_kwargs() -> None:
    fake = FakeTavilyClient(
        responses=[TavilySearchResult(query="q", results=[])],
    )
    await fake.search(
        query="q",
        include_domains=["nature.com"],
        depth="advanced",
        max_results=7,
    )
    assert fake.calls == [
        {
            "query": "q",
            "include_domains": ["nature.com"],
            "depth": "advanced",
            "max_results": 7,
        }
    ]


@pytest.fixture
def _no_retry_sleep(monkeypatch: pytest.MonkeyPatch) -> Iterator[None]:
    async def _no_sleep(_seconds: float) -> None:  # pragma: no cover - trivial
        return None

    monkeypatch.setattr("asyncio.sleep", _no_sleep)
    yield


@pytest.mark.asyncio
async def test_real_tavily_client_uses_advanced_depth_by_default(
    _no_retry_sleep: None,
) -> None:
    client = RealTavilyClient(api_key="tvly-test", source_tiers=load_source_tiers())
    captured: dict[str, object] = {}

    async def fake_search(query: str, **kwargs: object) -> dict[str, object]:
        captured["query"] = query
        captured.update(kwargs)
        return {"results": []}

    client._client.search = AsyncMock(side_effect=fake_search)
    await client.search(query="q", include_domains=["nature.com"], max_results=10)
    assert captured["search_depth"] == "advanced"


@pytest.mark.asyncio
async def test_real_tavily_client_derives_include_domains_from_config_when_none(
    _no_retry_sleep: None,
) -> None:
    client = RealTavilyClient(api_key="tvly-test", source_tiers=load_source_tiers())
    captured: dict[str, object] = {}

    async def fake_search(query: str, **kwargs: object) -> dict[str, object]:
        captured["query"] = query
        captured.update(kwargs)
        return {"results": []}

    client._client.search = AsyncMock(side_effect=fake_search)
    await client.search(query="q", include_domains=None, max_results=10)
    domains = captured["include_domains"]
    assert isinstance(domains, list)
    assert "nature.com" in domains
    assert "arxiv.org" in domains


@pytest.mark.asyncio
async def test_real_tavily_client_passes_through_explicit_include_domains(
    _no_retry_sleep: None,
) -> None:
    client = RealTavilyClient(api_key="tvly-test", source_tiers=load_source_tiers())
    captured: dict[str, object] = {}

    async def fake_search(query: str, **kwargs: object) -> dict[str, object]:
        captured.update(kwargs)
        return {"results": []}

    client._client.search = AsyncMock(side_effect=fake_search)
    await client.search(
        query="q",
        include_domains=["nature.com", "biorxiv.org"],
        max_results=5,
    )
    assert captured["include_domains"] == ["nature.com", "biorxiv.org"]


@pytest.mark.asyncio
async def test_real_tavily_client_raises_tavily_unavailable_after_retries(
    _no_retry_sleep: None,
) -> None:
    client = RealTavilyClient(api_key="tvly-test", source_tiers=load_source_tiers())
    call_count = 0

    async def boom(*_args: object, **_kwargs: object) -> dict[str, object]:
        nonlocal call_count
        call_count += 1
        raise RuntimeError("upstream broke")

    client._client.search = AsyncMock(side_effect=boom)
    with pytest.raises(TavilyUnavailable):
        await client.search(query="q", include_domains=["nature.com"], max_results=5)
    assert call_count >= 2
