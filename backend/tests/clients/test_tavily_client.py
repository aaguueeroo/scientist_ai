"""Tests for the Tavily client interface + fake (Step 18)."""

from __future__ import annotations

import pytest

from app.clients.tavily_client import (
    FakeTavilyClient,
    TavilyHit,
    TavilySearchResult,
)


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
