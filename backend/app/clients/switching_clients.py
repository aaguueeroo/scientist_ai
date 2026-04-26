"""OpenAI/Tavily clients that use per-request keys from context (or settings fallback)."""

from __future__ import annotations

from collections import OrderedDict
from typing import Any, TypeVar, cast

from app.api.provider_key_context import current_provider_keys
from app.clients.openai_client import (
    AbstractOpenAIClient,
    ChatMessage,
    ChatResult,
    CostTracker,
    ParsedResult,
    PriceTable,
    RealOpenAIClient,
)
from app.clients.tavily_client import (
    AbstractTavilyClient,
    RealTavilyClient,
    TavilyDepth,
    TavilyResearchModel,
    TavilySearchResult,
)
from app.config.settings import Settings
from app.config.source_tiers import SourceTiersConfig

T = TypeVar("T")

_MAX_CACHED_CLIENTS = 8


def _resolve_openai_key(settings: Settings) -> str:
    b = current_provider_keys()
    if b is not None:
        return b.openai
    o = settings.OPENAI_API_KEY.get_secret_value()
    if o:
        return o
    raise RuntimeError(
        "OpenAI API key not configured (no request context and empty OPENAI_API_KEY)",
    )


def _resolve_tavily_key(settings: Settings) -> str:
    b = current_provider_keys()
    if b is not None:
        return b.tavily
    t = settings.TAVILY_API_KEY.get_secret_value()
    if t:
        return t
    raise RuntimeError(
        "Tavily API key not configured (no request context and empty TAVILY_API_KEY)",
    )


class SwitchingOpenAIClient(AbstractOpenAIClient):
    """Delegates to :class:`RealOpenAIClient`, cached by resolved API key."""

    def __init__(self, *, settings: Settings, cost_tracker: CostTracker | None) -> None:
        self._settings = settings
        self.cost_tracker = cost_tracker
        self._cache: OrderedDict[str, RealOpenAIClient] = OrderedDict()

    def _client_for_current_key(self) -> RealOpenAIClient:
        key = _resolve_openai_key(self._settings)
        if key in self._cache:
            self._cache.move_to_end(key)
            return self._cache[key]
        client = RealOpenAIClient(api_key=key, cost_tracker=self.cost_tracker)
        self._cache[key] = client
        if len(self._cache) > _MAX_CACHED_CLIENTS:
            self._cache.popitem(last=False)
            # RealOpenAIClient.aclose is async — no sync eviction; rely on GC.
        return client

    async def chat(
        self,
        *,
        model: str,
        messages: list[ChatMessage],
        temperature: float,
        seed: int,
        max_tokens: int,
    ) -> ChatResult:
        return await self._client_for_current_key().chat(
            model=model,
            messages=messages,
            temperature=temperature,
            seed=seed,
            max_tokens=max_tokens,
        )

    async def parse(
        self,
        *,
        model: str,
        messages: list[ChatMessage],
        response_format: type[T],
        temperature: float,
        seed: int,
        max_tokens: int,
    ) -> ParsedResult[T]:
        inner = self._client_for_current_key()
        result = await inner.parse(
            model=model,
            messages=messages,
            response_format=response_format,
            temperature=temperature,
            seed=seed,
            max_tokens=max_tokens,
        )
        return cast(ParsedResult[T], result)

    async def aclose(self) -> None:
        for c in list(self._cache.values()):
            await c.aclose()
        self._cache.clear()


class SwitchingTavilyClient(AbstractTavilyClient):
    """Delegates to :class:`RealTavilyClient`, cached by resolved API key."""

    def __init__(
        self,
        *,
        settings: Settings,
        source_tiers: SourceTiersConfig,
    ) -> None:
        self._settings = settings
        self._source_tiers = source_tiers
        self._cache: OrderedDict[str, RealTavilyClient] = OrderedDict()

    def _client_for_current_key(self) -> RealTavilyClient:
        key = _resolve_tavily_key(self._settings)
        if key in self._cache:
            self._cache.move_to_end(key)
            return self._cache[key]
        client = RealTavilyClient(
            api_key=key,
            source_tiers=self._source_tiers,
            retrieval_mode=self._settings.TAVILY_RETRIEVAL_MODE,
            research_model=self._settings.TAVILY_RESEARCH_MODEL,
        )
        self._cache[key] = client
        if len(self._cache) > _MAX_CACHED_CLIENTS:
            self._cache.popitem(last=False)
        return client

    async def search(
        self,
        *,
        query: str,
        include_domains: list[str] | None,
        depth: TavilyDepth = "advanced",
        max_results: int = 10,
    ) -> TavilySearchResult:
        return await self._client_for_current_key().search(
            query=query,
            include_domains=include_domains,
            depth=depth,
            max_results=max_results,
        )

    async def search_web_wide(
        self,
        *,
        query: str,
        depth: TavilyDepth = "advanced",
        max_results: int = 10,
    ) -> TavilySearchResult:
        return await self._client_for_current_key().search_web_wide(
            query=query,
            depth=depth,
            max_results=max_results,
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
        return await self._client_for_current_key().search_raw(
            query=query,
            include_domains=include_domains,
            depth=depth,
            max_results=max_results,
            restrict_domains=restrict_domains,
        )

    async def research_raw(
        self,
        *,
        query: str,
        research_model: TavilyResearchModel = "mini",
    ) -> dict[str, Any]:
        return await self._client_for_current_key().research_raw(
            query=query,
            research_model=research_model,
        )

    async def aclose(self) -> None:
        for c in list(self._cache.values()):
            await c.aclose()
        self._cache.clear()


def build_switching_openai_client(settings: Settings) -> SwitchingOpenAIClient:
    prices = PriceTable(
        input_per_token={
            "gpt-4.1": settings.OPENAI_PRICE_INPUT_PER_TOKEN_GPT_4_1,
            "gpt-4.1-mini": settings.OPENAI_PRICE_INPUT_PER_TOKEN_GPT_4_1_MINI,
        },
        output_per_token={
            "gpt-4.1": settings.OPENAI_PRICE_OUTPUT_PER_TOKEN_GPT_4_1,
            "gpt-4.1-mini": settings.OPENAI_PRICE_OUTPUT_PER_TOKEN_GPT_4_1_MINI,
        },
    )
    cost_tracker = CostTracker(
        ceiling_usd=settings.MAX_REQUEST_USD,
        prices=prices,
    )
    return SwitchingOpenAIClient(settings=settings, cost_tracker=cost_tracker)


def build_switching_tavily_client(
    settings: Settings,
    source_tiers: SourceTiersConfig,
) -> SwitchingTavilyClient:
    return SwitchingTavilyClient(settings=settings, source_tiers=source_tiers)
