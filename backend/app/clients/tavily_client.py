"""Tavily client interface, value types, and an in-memory fake."""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Any, Literal

from pydantic import BaseModel, Field, HttpUrl

TavilyDepth = Literal["basic", "advanced"]


class TavilyHit(BaseModel):
    """One search hit returned by Tavily."""

    url: HttpUrl
    title: str = Field(min_length=1, max_length=500)
    snippet: str = Field(default="", max_length=4000)
    score: float = Field(ge=0.0, le=1.0)
    published_date: str | None = None


class TavilySearchResult(BaseModel):
    """Envelope of Tavily search results."""

    query: str
    results: list[TavilyHit] = Field(default_factory=list)


class AbstractTavilyClient(ABC):
    """Async Tavily client interface (used by runtime Agent 1)."""

    @abstractmethod
    async def search(
        self,
        *,
        query: str,
        include_domains: list[str],
        depth: TavilyDepth,
        max_results: int,
    ) -> TavilySearchResult:
        """Run a Tavily search; reject empty `include_domains`."""

    @abstractmethod
    async def aclose(self) -> None:
        """Release any underlying transport resources."""


class FakeTavilyClient(AbstractTavilyClient):
    """Deterministic in-memory client for unit tests."""

    def __init__(self, *, responses: list[TavilySearchResult] | None = None) -> None:
        self._queue: list[TavilySearchResult] = list(responses or [])
        self.calls: list[dict[str, Any]] = []
        self.closed = False

    async def search(
        self,
        *,
        query: str,
        include_domains: list[str],
        depth: TavilyDepth,
        max_results: int,
    ) -> TavilySearchResult:
        if not include_domains:
            raise ValueError(
                "Tavily search requires a non-empty include_domains allowlist; "
                "callers must pass the source-tier-derived domain list."
            )
        self.calls.append(
            {
                "query": query,
                "include_domains": list(include_domains),
                "depth": depth,
                "max_results": max_results,
            }
        )
        if not self._queue:
            raise AssertionError("FakeTavilyClient: no canned responses left")
        return self._queue.pop(0)

    async def aclose(self) -> None:
        self.closed = True
