"""Tavily client interface, value types, and an in-memory fake."""

from __future__ import annotations

import asyncio
import time
from abc import ABC, abstractmethod
from typing import Any, Literal, cast
from urllib.parse import urlparse

import httpx
from pydantic import BaseModel, Field, HttpUrl
from tavily import AsyncTavilyClient

from app.api.errors import TavilyUnavailable
from app.config.source_tiers import SourceTiersConfig

TavilyDepth = Literal["basic", "advanced"]
TavilyRetrievalMode = Literal["search", "research"]
TavilyResearchModel = Literal["mini", "pro", "auto"]


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
    async def search_web_wide(
        self,
        *,
        query: str,
        depth: TavilyDepth = "advanced",
        max_results: int = 10,
    ) -> TavilySearchResult:
        """Tavily Search with no ``include_domains`` (open web).

        Used only as a last resort when the tier allowlist returns nothing
        and we need at most one unverified similar link. Not used for
        ``/debug/tavily`` (that path uses :meth:`search_raw`).
        """

    @abstractmethod
    async def aclose(self) -> None:
        """Release any underlying transport resources."""

    @abstractmethod
    async def search_raw(
        self,
        *,
        query: str,
        include_domains: list[str] | None,
        depth: TavilyDepth = "basic",
        max_results: int = 5,
        restrict_domains: bool = True,
    ) -> dict[str, Any]:
        """Call Tavily Search (`/search`) and return the upstream response dict (for debugging).

        When ``restrict_domains`` is False, ``include_domains`` is ignored and Tavily
        may return any host (closer to the public Tavily play UI; not used by Agent 1).
        """

    @abstractmethod
    async def research_raw(
        self,
        *,
        query: str,
        research_model: TavilyResearchModel = "mini",
    ) -> dict[str, Any]:
        """Call Tavily Research (poll until `completed`); return the full last JSON body."""


class FakeTavilyClient(AbstractTavilyClient):
    """Deterministic in-memory client for unit tests."""

    def __init__(
        self,
        *,
        responses: list[TavilySearchResult] | None = None,
        web_wide_responses: list[TavilySearchResult] | None = None,
    ) -> None:
        self._queue: list[TavilySearchResult] = list(responses or [])
        self._web_wide_queue: list[TavilySearchResult] = list(web_wide_responses or [])
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

    async def search_web_wide(
        self,
        *,
        query: str,
        depth: TavilyDepth = "advanced",
        max_results: int = 10,
    ) -> TavilySearchResult:
        self.calls.append(
            {
                "kind": "search_web_wide",
                "query": query,
                "depth": depth,
                "max_results": max_results,
            }
        )
        if self._web_wide_queue:
            return self._web_wide_queue.pop(0)
        return TavilySearchResult(query=query, results=[])

    async def aclose(self) -> None:
        self.closed = True

    async def search_raw(
        self,
        *,
        query: str,
        include_domains: list[str] | None,
        depth: TavilyDepth = "basic",
        max_results: int = 5,
        restrict_domains: bool = True,
    ) -> dict[str, Any]:
        result = await self.search(
            query=query,
            include_domains=(include_domains if restrict_domains else None),
            depth=depth,
            max_results=max_results,
        )
        return {
            "query": result.query,
            "results": [
                {
                    "url": str(hit.url),
                    "title": hit.title,
                    "content": hit.snippet,
                    "score": hit.score,
                    "published_date": hit.published_date,
                }
                for hit in result.results
            ],
        }

    async def research_raw(
        self,
        *,
        query: str,
        research_model: TavilyResearchModel = "mini",
    ) -> dict[str, Any]:
        return {
            "status": "completed",
            "input": query,
            "model": research_model,
            "sources": [
                {
                    "url": "https://www.nature.com/articles/fake-123",
                    "title": "Stub research source",
                }
            ],
            "content": "Stub Tavily Research response for unit tests.",
        }


class RealTavilyClient(AbstractTavilyClient):
    """`tavily-python` Search and/or httpx Research with tier-derived allowlist."""

    _MAX_ATTEMPTS = 3
    _RESEARCH_POLL_S = 1.0
    _RESEARCH_MAX_WAIT_S = 120.0

    def __init__(
        self,
        *,
        api_key: str,
        source_tiers: SourceTiersConfig,
        retrieval_mode: TavilyRetrievalMode = "search",
        research_model: TavilyResearchModel = "mini",
    ) -> None:
        if not api_key:
            raise TavilyUnavailable("TAVILY_API_KEY is empty; configure it in the environment.")
        self._api_key = api_key
        self._client = AsyncTavilyClient(api_key=api_key)
        self._source_tiers = source_tiers
        self._retrieval_mode: TavilyRetrievalMode = retrieval_mode
        self._research_model: TavilyResearchModel = research_model
        # Used only for POST/GET /research (not exposed by tavily-python 0.7.x).
        self._research_http: httpx.AsyncClient | None = None
        if retrieval_mode == "research":
            self._research_http = self._new_research_httpx()

    def _new_research_httpx(self) -> httpx.AsyncClient:
        return httpx.AsyncClient(
            base_url="https://api.tavily.com",
            headers={
                "Authorization": f"Bearer {self._api_key}",
                "Content-Type": "application/json",
            },
            timeout=httpx.Timeout(10.0, read=120.0, write=10.0, pool=5.0),
        )

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

        if self._retrieval_mode == "research":
            if self._research_http is None:
                raise TavilyUnavailable(
                    "Tavily research client misconfigured: missing HTTP client",
                    details={},
                )
            return await self._search_via_research(
                query=query,
                include_domains=domains,
                max_results=max_results,
            )

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

    async def search_web_wide(
        self,
        *,
        query: str,
        depth: TavilyDepth = "advanced",
        max_results: int = 10,
    ) -> TavilySearchResult:
        last_error: BaseException | None = None
        for attempt in range(self._MAX_ATTEMPTS):
            try:
                raw: dict[str, Any] = await self._client.search(
                    query,
                    search_depth=depth,
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

    async def search_raw(
        self,
        *,
        query: str,
        include_domains: list[str] | None,
        depth: TavilyDepth = "basic",
        max_results: int = 5,
        restrict_domains: bool = True,
    ) -> dict[str, Any]:
        last_error: BaseException | None = None
        if not restrict_domains:
            for attempt in range(self._MAX_ATTEMPTS):
                try:
                    raw = await self._client.search(
                        query,
                        search_depth=depth,
                        max_results=max_results,
                    )
                    return cast(dict[str, Any], raw)
                except Exception as err:
                    last_error = err
                    if attempt < self._MAX_ATTEMPTS - 1:
                        await asyncio.sleep(0.05 * (2**attempt))
            raise TavilyUnavailable(
                f"Tavily search failed after {self._MAX_ATTEMPTS} attempts",
                details={"last_error": repr(last_error) if last_error else ""},
            )

        domains = (
            list(include_domains)
            if include_domains is not None
            else self._source_tiers.tavily_include_domains()
        )
        if not domains:
            raise ValueError("Tavily search requires a non-empty include_domains allowlist.")

        for attempt in range(self._MAX_ATTEMPTS):
            try:
                raw: dict[str, Any] = await self._client.search(
                    query,
                    search_depth=depth,
                    include_domains=domains,
                    max_results=max_results,
                )
                return raw
            except Exception as err:
                last_error = err
                if attempt < self._MAX_ATTEMPTS - 1:
                    await asyncio.sleep(0.05 * (2**attempt))
        raise TavilyUnavailable(
            f"Tavily search failed after {self._MAX_ATTEMPTS} attempts",
            details={"last_error": repr(last_error)},
        )

    async def research_raw(
        self,
        *,
        query: str,
        research_model: TavilyResearchModel = "mini",
    ) -> dict[str, Any]:
        """Run Research to completion.

        Uses the long-lived client when `retrieval_mode=research`, else a one-off httpx client.
        """

        if self._research_http is not None:
            return await self._poll_research_to_completion(
                self._research_http, query, research_model
            )
        async with self._new_research_httpx() as client:
            return await self._poll_research_to_completion(client, query, research_model)

    async def aclose(self) -> None:
        close = getattr(self._client, "close", None)
        if close is not None:
            await close()
        if self._research_http is not None:
            await self._research_http.aclose()

    async def _search_via_research(
        self,
        *,
        query: str,
        include_domains: list[str],
        max_results: int,
    ) -> TavilySearchResult:
        """Run Tavily Research API; keep sources whose host is on the tier allowlist."""

        assert self._research_http is not None
        data = await self._poll_research_to_completion(
            self._research_http, query, self._research_model
        )
        return _research_completed_to_result(
            query=query,
            data=data,
            include_domains=include_domains,
            max_results=max_results,
        )

    async def _poll_research_to_completion(
        self,
        http: httpx.AsyncClient,
        query: str,
        model: TavilyResearchModel,
    ) -> dict[str, Any]:
        """POST /research, poll until completed; return the final JSON body."""

        create_payload: dict[str, Any] = {
            "input": query,
            "model": model,
            "stream": False,
        }
        last_error: BaseException | None = None
        for attempt in range(self._MAX_ATTEMPTS):
            try:
                create = await http.post("/research", json=create_payload)
                if create.status_code not in (200, 201):
                    last_error = RuntimeError(f"create research HTTP {create.status_code}")
                    continue
                body = create.json()
                request_id = body.get("request_id")
                if not request_id or not isinstance(request_id, str):
                    last_error = RuntimeError("research create missing request_id")
                    continue

                deadline = time.monotonic() + self._RESEARCH_MAX_WAIT_S
                while time.monotonic() < deadline:
                    resp = await http.get(f"/research/{request_id}")
                    if resp.status_code == 202:
                        await asyncio.sleep(self._RESEARCH_POLL_S)
                        continue
                    if resp.status_code != 200:
                        last_error = RuntimeError(f"poll research HTTP {resp.status_code}")
                        break
                    data = resp.json()
                    st = data.get("status")
                    if st in ("pending", "in_progress"):
                        await asyncio.sleep(self._RESEARCH_POLL_S)
                        continue
                    if st == "failed":
                        raise TavilyUnavailable(
                            "Tavily research task failed",
                            details={"request_id": request_id, "body": data},
                        )
                    if st == "completed":
                        return cast(dict[str, Any], data)
                    last_error = RuntimeError(f"unknown research status {st!r}")
                    break
                else:
                    last_error = TimeoutError("Tavily research poll exceeded max wait")
            except (TavilyUnavailable, ValueError):
                raise
            except Exception as err:
                last_error = err
            if attempt < self._MAX_ATTEMPTS - 1:
                await asyncio.sleep(0.05 * (2**attempt))
        raise TavilyUnavailable(
            f"Tavily research failed after {self._MAX_ATTEMPTS} attempts",
            details={"last_error": repr(last_error) if last_error is not None else ""},
        )


def _url_on_allowlist(url: str, allow_domains: list[str]) -> bool:
    host = (urlparse(url).hostname or "").lower()
    if not host:
        return False
    for d in allow_domains:
        dl = d.lower().strip()
        if not dl:
            continue
        if host == dl or host.endswith(f".{dl}"):
            return True
    return False


def _research_completed_to_result(
    *,
    query: str,
    data: dict[str, Any],
    include_domains: list[str],
    max_results: int,
) -> TavilySearchResult:
    raw_sources = data.get("sources") or []
    if not isinstance(raw_sources, list):
        raw_sources = []

    hits: list[TavilyHit] = []
    n = 0.0
    for src in raw_sources:
        if not isinstance(src, dict):
            continue
        u = src.get("url")
        if not u or not isinstance(u, str):
            continue
        if not _url_on_allowlist(u, include_domains):
            continue
        title = str(src.get("title") or "(untitled)")[:500]
        if not title.strip():
            title = "(untitled)"
        score = max(0.0, 1.0 - n * 0.01)
        n += 1.0
        hits.append(TavilyHit(url=u, title=title, snippet="", score=score, published_date=None))
        if len(hits) >= max_results:
            break

    return TavilySearchResult(query=query, results=hits)


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
