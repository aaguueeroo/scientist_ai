"""OpenAI client interface, value types, fake, real, and cost-ceiling enforcement."""

from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Any, Generic, Literal, TypeVar, cast

from openai import (
    APIConnectionError,
    APIStatusError,
    APITimeoutError,
    AsyncOpenAI,
    AuthenticationError,
    InternalServerError,
    OpenAIError,
    RateLimitError,
)
from pydantic import BaseModel, Field

from app.api.errors import (
    CostCeilingExceeded,
    OpenAIRateLimited,
    OpenAIUnavailable,
    StructuredOutputInvalid,
)

ChatRole = Literal["system", "user", "assistant"]


class ChatMessage(BaseModel):
    """A single message in a chat-completions style call."""

    role: ChatRole
    content: str


class TokenUsage(BaseModel):
    """Token counts reported by the OpenAI usage block."""

    prompt_tokens: int = Field(ge=0)
    completion_tokens: int = Field(ge=0)


class ChatResult(BaseModel):
    """Plain-text response returned by `chat`."""

    content: str
    usage: TokenUsage
    model: str


T = TypeVar("T", bound=BaseModel)


class ParsedResult(BaseModel, Generic[T]):
    """Structured-output response returned by `parse`."""

    model_config = {"arbitrary_types_allowed": True}

    parsed: T
    usage: TokenUsage
    model: str


@dataclass(frozen=True)
class PriceTable:
    """Per-token USD prices for each pinned model."""

    input_per_token: dict[str, float]
    output_per_token: dict[str, float]

    def cost_for(self, *, model: str, prompt_tokens: int, completion_tokens: int) -> float:
        return prompt_tokens * self.input_per_token.get(
            model, 0.0
        ) + completion_tokens * self.output_per_token.get(model, 0.0)

    def projected_cost_for(
        self,
        *,
        model: str,
        prompt_chars: int,
        max_tokens: int,
    ) -> float:
        """Pre-call worst-case projection.

        We do not depend on tiktoken here: the wrapper estimates input
        tokens from `prompt_chars / 4` (a standard rule-of-thumb) and
        assumes the model emits up to `max_tokens` completion tokens.
        """

        estimated_prompt_tokens = max(1, prompt_chars // 4)
        return estimated_prompt_tokens * self.input_per_token.get(
            model, 0.0
        ) + max_tokens * self.output_per_token.get(model, 0.0)


@dataclass
class CostTracker:
    """Per-request cumulative cost tracker enforced by the OpenAI wrapper."""

    ceiling_usd: float
    prices: PriceTable
    total_usd: float = 0.0
    calls: list[dict[str, Any]] = field(default_factory=list)

    def check_projected(self, *, model: str, prompt_chars: int, max_tokens: int) -> None:
        projected = self.prices.projected_cost_for(
            model=model, prompt_chars=prompt_chars, max_tokens=max_tokens
        )
        if self.total_usd + projected > self.ceiling_usd:
            raise CostCeilingExceeded(
                f"projected cost ${self.total_usd + projected:.4f} would exceed "
                f"ceiling ${self.ceiling_usd:.4f}",
                details={
                    "model": model,
                    "current_usd": self.total_usd,
                    "projected_usd": projected,
                    "ceiling_usd": self.ceiling_usd,
                },
            )

    def record(self, *, model: str, usage: TokenUsage) -> None:
        cost = self.prices.cost_for(
            model=model,
            prompt_tokens=usage.prompt_tokens,
            completion_tokens=usage.completion_tokens,
        )
        self.total_usd += cost
        self.calls.append({"model": model, "cost_usd": cost})


class AbstractOpenAIClient(ABC):
    """Async OpenAI client interface used by every runtime agent."""

    @abstractmethod
    async def chat(
        self,
        *,
        model: str,
        messages: list[ChatMessage],
        temperature: float,
        seed: int,
        max_tokens: int,
    ) -> ChatResult:
        """Chat completion with no structured output."""

    @abstractmethod
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
        """Structured output parsed into `response_format`."""

    @abstractmethod
    async def aclose(self) -> None:
        """Release any underlying transport resources."""


def _prompt_chars(messages: list[ChatMessage]) -> int:
    return sum(len(m.content) for m in messages)


def _to_api_messages(messages: list[ChatMessage]) -> list[dict[str, str]]:
    """Map internal messages to the JSON shape the OpenAI SDK accepts."""

    return [{"role": m.role, "content": m.content} for m in messages]


def _token_usage_from_api(usage: object | None) -> TokenUsage:
    if usage is None:
        return TokenUsage(prompt_tokens=0, completion_tokens=0)
    return TokenUsage(
        prompt_tokens=int(getattr(usage, "prompt_tokens", 0) or 0),
        completion_tokens=int(getattr(usage, "completion_tokens", 0) or 0),
    )


def _reraise_as_domain_error(exc: OpenAIError) -> None:
    """Translate `openai` transport/API failures into :class:`DomainError` subtypes."""

    if isinstance(exc, RateLimitError):
        raise OpenAIRateLimited(
            f"OpenAI rate limit: {exc!s}",
            details={"type": type(exc).__name__},
        ) from exc
    if isinstance(exc, AuthenticationError):
        raise OpenAIUnavailable(
            "OpenAI authentication failed; check OPENAI_API_KEY",
            details={"type": type(exc).__name__},
        ) from exc
    if isinstance(
        exc,
        (
            APIConnectionError,
            APITimeoutError,
        ),
    ):
        raise OpenAIUnavailable(
            f"OpenAI request failed: {exc!s}",
            details={"type": type(exc).__name__},
        ) from exc
    if isinstance(exc, InternalServerError):
        raise OpenAIUnavailable(
            "OpenAI returned a server error",
            details={"type": type(exc).__name__},
        ) from exc
    if isinstance(exc, APIStatusError):
        sc = int(getattr(exc, "status_code", 0) or 0)
        if sc == 429:
            raise OpenAIRateLimited(
                f"OpenAI rate limit (HTTP 429): {exc!s}",
                details={"status_code": 429, "type": type(exc).__name__},
            ) from exc
        if sc >= 500:
            raise OpenAIUnavailable(
                f"OpenAI error: {exc!s}",
                details={"status_code": sc, "type": type(exc).__name__},
            ) from exc
        if sc in (401, 403):
            raise OpenAIUnavailable(
                "OpenAI authentication failed; check OPENAI_API_KEY",
                details={"status_code": sc, "type": type(exc).__name__},
            ) from exc
    raise OpenAIUnavailable(
        f"OpenAI error: {exc!s}",
        details={"type": type(exc).__name__},
    ) from exc


class FakeOpenAIClient(AbstractOpenAIClient):
    """Deterministic in-memory client for unit tests."""

    def __init__(
        self,
        *,
        chat_responses: list[ChatResult | BaseException] | None = None,
        parsed_responses: list[ParsedResult[Any] | BaseException] | None = None,
        cost_tracker: CostTracker | None = None,
    ) -> None:
        self._chat_queue: list[ChatResult | BaseException] = list(chat_responses or [])
        self._parsed_queue: list[ParsedResult[Any] | BaseException] = list(parsed_responses or [])
        self.calls: list[dict[str, Any]] = []
        self.closed = False
        self.cost_tracker = cost_tracker

    async def chat(
        self,
        *,
        model: str,
        messages: list[ChatMessage],
        temperature: float,
        seed: int,
        max_tokens: int,
    ) -> ChatResult:
        if self.cost_tracker is not None:
            self.cost_tracker.check_projected(
                model=model, prompt_chars=_prompt_chars(messages), max_tokens=max_tokens
            )
        self.calls.append(
            {
                "kind": "chat",
                "model": model,
                "messages": messages,
                "temperature": temperature,
                "seed": seed,
                "max_tokens": max_tokens,
            }
        )
        if not self._chat_queue:
            raise AssertionError("FakeOpenAIClient: no canned chat responses left")
        next_item = self._chat_queue.pop(0)
        if isinstance(next_item, BaseException):
            raise next_item
        if self.cost_tracker is not None:
            self.cost_tracker.record(model=model, usage=next_item.usage)
        return next_item

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
        if self.cost_tracker is not None:
            self.cost_tracker.check_projected(
                model=model, prompt_chars=_prompt_chars(messages), max_tokens=max_tokens
            )
        self.calls.append(
            {
                "kind": "parse",
                "model": model,
                "messages": messages,
                "response_format": response_format,
                "temperature": temperature,
                "seed": seed,
                "max_tokens": max_tokens,
            }
        )
        if not self._parsed_queue:
            raise AssertionError("FakeOpenAIClient: no canned parsed responses left")
        next_item = self._parsed_queue.pop(0)
        if isinstance(next_item, BaseException):
            raise next_item
        if not isinstance(next_item.parsed, response_format):
            raise AssertionError(
                "FakeOpenAIClient: canned parsed response type does not match "
                f"response_format={response_format!r}"
            )
        if self.cost_tracker is not None:
            self.cost_tracker.record(model=model, usage=next_item.usage)
        return next_item

    async def aclose(self) -> None:
        self.closed = True


class RealOpenAIClient(AbstractOpenAIClient):
    """`openai.AsyncOpenAI`-backed implementation."""

    def __init__(self, *, api_key: str, cost_tracker: CostTracker | None = None) -> None:
        if not api_key:
            raise OpenAIUnavailable("OPENAI_API_KEY is empty; configure it in the environment.")
        self._client = AsyncOpenAI(api_key=api_key)
        self.cost_tracker = cost_tracker

    async def chat(
        self,
        *,
        model: str,
        messages: list[ChatMessage],
        temperature: float,
        seed: int,
        max_tokens: int,
    ) -> ChatResult:
        if self.cost_tracker is not None:
            self.cost_tracker.check_projected(
                model=model, prompt_chars=_prompt_chars(messages), max_tokens=max_tokens
            )
        try:
            response = await self._client.chat.completions.create(
                model=model,
                messages=cast(Any, _to_api_messages(messages)),
                temperature=temperature,
                seed=seed,
                max_tokens=max_tokens,
            )
        except OpenAIError as exc:
            _reraise_as_domain_error(exc)
        assert response.choices
        first = response.choices[0].message
        text = (first.content or "").strip()
        ut = _token_usage_from_api(response.usage)
        if self.cost_tracker is not None:
            self.cost_tracker.record(model=model, usage=ut)
        return ChatResult(
            content=text,
            usage=ut,
            model=(response.model or model),
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
        """Structured output. ``response_format`` must follow OpenAI's JSON Schema subset; in
        this repo use :class:`app.schemas.openai_structured_model.OpenAIStructuredModel`.
        https://developers.openai.com/api/docs/guides/structured-outputs#supported-schemas
        """

        if self.cost_tracker is not None:
            self.cost_tracker.check_projected(
                model=model, prompt_chars=_prompt_chars(messages), max_tokens=max_tokens
            )
        try:
            completion = await self._client.chat.completions.parse(
                model=model,
                messages=cast(Any, _to_api_messages(messages)),
                response_format=response_format,
                temperature=temperature,
                seed=seed,
                max_tokens=max_tokens,
            )
        except OpenAIError as exc:
            _reraise_as_domain_error(exc)
        assert completion.choices
        message = completion.choices[0].message
        raw: object = message.parsed
        if raw is None:
            refusal = getattr(message, "refusal", None)
            if refusal:
                raise StructuredOutputInvalid(
                    f"OpenAI model refusal: {refusal!s}",
                    details={"refusal": str(refusal)[:2_000]},
                )
            raise StructuredOutputInvalid(
                "no structured object returned by OpenAI",
                details={"reason": "empty_parsed", "type": "openai.parse"},
            )
        if isinstance(raw, response_format):
            out: T = raw
        else:
            out = response_format.model_validate(raw)
        ut = _token_usage_from_api(completion.usage)
        if self.cost_tracker is not None:
            self.cost_tracker.record(model=model, usage=ut)
        return ParsedResult(
            parsed=out,
            usage=ut,
            model=(completion.model or model),
        )

    async def aclose(self) -> None:
        await self._client.close()
