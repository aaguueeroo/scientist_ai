"""Tavily client interface, value types, and an in-memory fake."""

from __future__ import annotations

import asyncio
from abc import ABC, abstractmethod
from typing import Any, Literal

from pydantic import BaseModel, Field, HttpUrl
from tavily import AsyncTavilyClient

from app.api.errors import TavilyUnavailable
from app.config.source_tiers import SourceTiersConfig

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
        include_domains: list[str] | None,
        depth: TavilyDepth = "advanced",
        max_results: int = 10,
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
        include_domains: list[str] | None,
        depth: TavilyDepth = "advanced",
        max_results: int = 10,
    ) -> TavilySearchResult:
        if include_domains is not None and not include_domains:
            raise ValueError(
                "Tavily search requires a non-empty include_domains allowlist; "
                "callers must pass the source-tier-derived domain list."
            )
        self.calls.append(
            {
                "query": query,
                "include_domains": list(include_domains) if include_domains else [],
                "depth": depth,
                "max_results": max_results,
            }
        )
        if not self._queue:
            raise AssertionError("FakeTavilyClient: no canned responses left")
        return self._queue.pop(0)

    async def aclose(self) -> None:
        self.closed = True


class RealTavilyClient(AbstractTavilyClient):
    """`tavily-python`-backed implementation with retry + tier-derived allowlist."""

    _MAX_ATTEMPTS = 3

    def __init__(
        self,
        *,
        api_key: str,
        source_tiers: SourceTiersConfig,
    ) -> None:
        if not api_key:
            raise TavilyUnavailable("TAVILY_API_KEY is empty; configure it in the environment.")
        self._client = AsyncTavilyClient(api_key=api_key)
        self._source_tiers = source_tiers

    async def search(
        self,
        *,
        query: str,
        include_domains: list[str] | None,
        depth: TavilyDepth = "advanced",
        max_results: int = 10,
    ) -> TavilySearchResult:
        domains = (
            list(include_domains)
            if include_domains is not None
            else self._source_tiers.tavily_include_domains()
        )
        if not domains:
            raise ValueError("Tavily search requires a non-empty include_domains allowlist.")

        last_error: BaseException | None = None
        for attempt in range(self._MAX_ATTEMPTS):
            try:
                raw = await self._client.search(
                    query,
                    search_depth=depth,
                    include_domains=domains,
                    max_results=max_results,
                )
                return _coerce_result(query, raw)
            except Exception as err:
                last_error = err
                if attempt < self._MAX_ATTEMPTS - 1:
                    await asyncio.sleep(0.05 * (2**attempt))
        raise TavilyUnavailable(
            f"Tavily search failed after {self._MAX_ATTEMPTS} attempts",
            details={"last_error": repr(last_error)},
        )

    async def aclose(self) -> None:
        close = getattr(self._client, "close", None)
        if close is not None:
            await close()


def _coerce_result(query: str, raw: dict[str, Any]) -> TavilySearchResult:
    hits: list[TavilyHit] = []
    for entry in raw.get("results", []):
        hits.append(
            TavilyHit(
                url=entry["url"],
                title=entry.get("title", "(untitled)"),
                snippet=entry.get("content", "") or entry.get("snippet", ""),
                score=float(entry.get("score", 0.0)),
                published_date=entry.get("published_date"),
            )
        )
    return TavilySearchResult(query=query, results=hits)
