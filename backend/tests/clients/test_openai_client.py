"""Tests for the OpenAI client interface + fake (Step 15)."""

from __future__ import annotations

import pytest
from pydantic import BaseModel

from app.api.errors import CostCeilingExceeded, OpenAIUnavailable
from app.clients.openai_client import (
    ChatMessage,
    ChatResult,
    CostTracker,
    FakeOpenAIClient,
    ParsedResult,
    PriceTable,
    RealOpenAIClient,
    TokenUsage,
)


@pytest.mark.asyncio
async def test_fake_openai_client_returns_canned_chat_response() -> None:
    fake = FakeOpenAIClient(
        chat_responses=[
            ChatResult(
                content="canned reply",
                usage=TokenUsage(prompt_tokens=10, completion_tokens=4),
                model="gpt-4.1-mini",
            )
        ]
    )
    result = await fake.chat(
        model="gpt-4.1-mini",
        messages=[ChatMessage(role="user", content="hello")],
        temperature=0.0,
        seed=7,
        max_tokens=128,
    )
    assert result.content == "canned reply"
    assert result.usage.prompt_tokens == 10


class _Out(BaseModel):
    answer: str


@pytest.mark.asyncio
async def test_fake_openai_client_returns_canned_parsed_response() -> None:
    fake = FakeOpenAIClient(
        parsed_responses=[
            ParsedResult(
                parsed=_Out(answer="42"),
                usage=TokenUsage(prompt_tokens=5, completion_tokens=2),
                model="gpt-4.1",
            )
        ]
    )
    result = await fake.parse(
        model="gpt-4.1",
        messages=[ChatMessage(role="user", content="give me 42")],
        response_format=_Out,
        temperature=0.0,
        seed=23,
        max_tokens=64,
    )
    assert isinstance(result.parsed, _Out)
    assert result.parsed.answer == "42"


@pytest.mark.asyncio
async def test_fake_openai_client_records_call_kwargs() -> None:
    fake = FakeOpenAIClient(
        chat_responses=[
            ChatResult(
                content="ok",
                usage=TokenUsage(prompt_tokens=1, completion_tokens=1),
                model="gpt-4.1-mini",
            )
        ]
    )
    await fake.chat(
        model="gpt-4.1-mini",
        messages=[
            ChatMessage(role="system", content="role"),
            ChatMessage(role="user", content="hi"),
        ],
        temperature=0.0,
        seed=11,
        max_tokens=256,
    )
    assert len(fake.calls) == 1
    call = fake.calls[0]
    assert call["model"] == "gpt-4.1-mini"
    assert call["temperature"] == 0.0
    assert call["seed"] == 11
    assert call["max_tokens"] == 256
    assert call["messages"][0].role == "system"


def test_real_openai_client_missing_key_raises_clear_error() -> None:
    with pytest.raises(OpenAIUnavailable):
        RealOpenAIClient(api_key="")


@pytest.mark.asyncio
async def test_real_openai_client_aclose_closes_underlying_async_client() -> None:
    client = RealOpenAIClient(api_key="sk-test-not-real")
    closed_calls: list[int] = []

    async def fake_close() -> None:
        closed_calls.append(1)

    client._client.close = fake_close  # type: ignore[method-assign]  # injected stub for test
    await client.aclose()
    assert closed_calls == [1]


def _price_table() -> PriceTable:
    return PriceTable(
        input_per_token={
            "gpt-4.1": 2.0e-6,
            "gpt-4.1-mini": 0.4e-6,
        },
        output_per_token={
            "gpt-4.1": 8.0e-6,
            "gpt-4.1-mini": 1.6e-6,
        },
    )


@pytest.mark.asyncio
async def test_openai_client_records_cost_after_successful_call() -> None:
    tracker = CostTracker(ceiling_usd=0.60, prices=_price_table())
    fake = FakeOpenAIClient(
        chat_responses=[
            ChatResult(
                content="ok",
                usage=TokenUsage(prompt_tokens=1000, completion_tokens=500),
                model="gpt-4.1-mini",
            )
        ],
        cost_tracker=tracker,
    )
    await fake.chat(
        model="gpt-4.1-mini",
        messages=[ChatMessage(role="user", content="hello")],
        temperature=0.0,
        seed=7,
        max_tokens=512,
    )
    expected = 1000 * 0.4e-6 + 500 * 1.6e-6
    assert tracker.total_usd == pytest.approx(expected)


@pytest.mark.asyncio
async def test_openai_client_refuses_call_when_projected_cost_exceeds_ceiling() -> None:
    tracker = CostTracker(ceiling_usd=0.001, prices=_price_table())
    fake = FakeOpenAIClient(
        chat_responses=[
            ChatResult(
                content="ok",
                usage=TokenUsage(prompt_tokens=10, completion_tokens=10),
                model="gpt-4.1",
            )
        ],
        cost_tracker=tracker,
    )
    with pytest.raises(CostCeilingExceeded):
        await fake.chat(
            model="gpt-4.1",
            messages=[ChatMessage(role="user", content="x" * 5000)],
            temperature=0.0,
            seed=23,
            max_tokens=4000,
        )
    assert tracker.total_usd == 0.0


@pytest.mark.asyncio
async def test_openai_client_summed_cost_across_calls_compares_against_ceiling() -> None:
    tracker = CostTracker(ceiling_usd=0.005, prices=_price_table())
    fake = FakeOpenAIClient(
        chat_responses=[
            ChatResult(
                content="a",
                usage=TokenUsage(prompt_tokens=2000, completion_tokens=1000),
                model="gpt-4.1-mini",
            ),
            ChatResult(
                content="b",
                usage=TokenUsage(prompt_tokens=2000, completion_tokens=1000),
                model="gpt-4.1-mini",
            ),
        ],
        cost_tracker=tracker,
    )
    await fake.chat(
        model="gpt-4.1-mini",
        messages=[ChatMessage(role="user", content="first")],
        temperature=0.0,
        seed=7,
        max_tokens=1024,
    )
    with pytest.raises(CostCeilingExceeded):
        await fake.chat(
            model="gpt-4.1-mini",
            messages=[ChatMessage(role="user", content="second")],
            temperature=0.0,
            seed=7,
            max_tokens=4000,
        )
    first_call_cost = 2000 * 0.4e-6 + 1000 * 1.6e-6
    assert tracker.total_usd == pytest.approx(first_call_cost)
