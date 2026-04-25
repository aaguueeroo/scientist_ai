"""OpenAI client interface, value types, and an in-memory fake."""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Any, Generic, Literal, TypeVar

from openai import AsyncOpenAI
from pydantic import BaseModel, Field

from app.api.errors import OpenAIUnavailable

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


class FakeOpenAIClient(AbstractOpenAIClient):
    """Deterministic in-memory client for unit tests."""

    def __init__(
        self,
        *,
        chat_responses: list[ChatResult] | None = None,
        parsed_responses: list[ParsedResult[Any]] | None = None,
    ) -> None:
        self._chat_queue: list[ChatResult] = list(chat_responses or [])
        self._parsed_queue: list[ParsedResult[Any]] = list(parsed_responses or [])
        self.calls: list[dict[str, Any]] = []
        self.closed = False

    async def chat(
        self,
        *,
        model: str,
        messages: list[ChatMessage],
        temperature: float,
        seed: int,
        max_tokens: int,
    ) -> ChatResult:
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
        return self._chat_queue.pop(0)

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
        result = self._parsed_queue.pop(0)
        if not isinstance(result.parsed, response_format):
            raise AssertionError(
                "FakeOpenAIClient: canned parsed response type does not match "
                f"response_format={response_format!r}"
            )
        return result

    async def aclose(self) -> None:
        self.closed = True


class RealOpenAIClient(AbstractOpenAIClient):
    """`openai.AsyncOpenAI`-backed implementation."""

    def __init__(self, *, api_key: str) -> None:
        if not api_key:
            raise OpenAIUnavailable("OPENAI_API_KEY is empty; configure it in the environment.")
        self._client = AsyncOpenAI(api_key=api_key)

    async def chat(
        self,
        *,
        model: str,
        messages: list[ChatMessage],
        temperature: float,
        seed: int,
        max_tokens: int,
    ) -> ChatResult:
        raise NotImplementedError

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
        raise NotImplementedError

    async def aclose(self) -> None:
        await self._client.close()
