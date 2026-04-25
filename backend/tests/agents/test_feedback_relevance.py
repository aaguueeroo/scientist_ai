"""Tests for runtime Agent 2 (Feedback relevance) — Step 41.

Agent 2 makes two LLM calls per `docs/research.md` §7:
1. Domain extraction — closed-enum, schema-enforced (`gpt-4.1-mini`).
2. Relevance rerank — scores each candidate correction in `[0.0, 1.0]`.

The agent is exercised against the `FeedbackRepo` (real, in-memory
SQLite via the same `db.py` factory the production code uses) so the
"two-call" pipeline + repo lookup are tested end-to-end against fakes.
"""

from __future__ import annotations

import asyncio
import json
import logging
from collections.abc import AsyncIterator

import pytest
import pytest_asyncio
from pydantic import SecretStr
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.agents.feedback_relevance import (
    DomainTagClaim,
    FeedbackRelevanceAgent,
    RelevanceClaim,
    RelevanceItem,
)
from app.clients.openai_client import (
    ChatMessage,
    FakeOpenAIClient,
    ParsedResult,
    TokenUsage,
)
from app.config.settings import Settings
from app.observability.logging import configure_logging
from app.schemas.feedback import DomainTag, FeedbackRecord
from app.storage import db as db_module
from app.storage.feedback_repo import FeedbackRepo


def _settings() -> Settings:
    return Settings(
        OPENAI_API_KEY=SecretStr("sk-test"),
        TAVILY_API_KEY=SecretStr("tvly-test"),
        DATABASE_URL="sqlite+aiosqlite:///:memory:",
    )


@pytest_asyncio.fixture
async def session_factory() -> AsyncIterator[async_sessionmaker[AsyncSession]]:
    engine = db_module.create_engine(_settings())
    await db_module.create_all(engine)
    factory = db_module.async_session(engine)
    try:
        yield factory
    finally:
        await engine.dispose()


_PROMPT_VERSIONS: dict[str, str] = {
    "literature_qc.md": "qc",
    "feedback_relevance.md": "fb",
    "experiment_planner.md": "ep",
}


def _domain_response(tag: DomainTag) -> ParsedResult[DomainTagClaim]:
    return ParsedResult(
        parsed=DomainTagClaim(domain_tag=tag),
        usage=TokenUsage(prompt_tokens=20, completion_tokens=4),
        model="gpt-4.1-mini",
    )


def _relevance_response(items: list[RelevanceItem]) -> ParsedResult[RelevanceClaim]:
    return ParsedResult(
        parsed=RelevanceClaim(items=items),
        usage=TokenUsage(prompt_tokens=80, completion_tokens=40),
        model="gpt-4.1-mini",
    )


async def _seed(
    repo: FeedbackRepo,
    *,
    feedback_id: str,
    domain_tag: DomainTag,
    after: str = "Sigma-Aldrich trehalose",
) -> FeedbackRecord:
    record = FeedbackRecord(
        feedback_id=feedback_id,
        plan_id="plan-seed-001",
        domain_tag=domain_tag,
        corrected_field="materials[0].vendor",
        before="acme",
        after=after,
        reason="standard supplier per published protocol",
    )
    await repo.save(
        record=record,
        prompt_versions=_PROMPT_VERSIONS,
        request_id=f"req-{feedback_id}",
    )
    return record


@pytest.mark.asyncio
async def test_feedback_relevance_extracts_correct_domain_tag(
    session_factory: async_sessionmaker[AsyncSession],
) -> None:
    repo = FeedbackRepo(session_factory)
    openai = FakeOpenAIClient(
        parsed_responses=[
            _domain_response(DomainTag.DIAGNOSTICS_BIOSENSOR),
        ],
    )

    agent = FeedbackRelevanceAgent(openai=openai, settings=_settings())

    examples = await agent.run(
        hypothesis=("A paper-based lateral-flow biosensor for CRP detection at point-of-care."),
        repo=repo,
        request_id="req-domain-1",
    )

    assert examples == []
    assert openai.calls, "Expected at least one OpenAI parse call for domain extraction"
    domain_call = openai.calls[0]
    assert domain_call["model"] == "gpt-4.1-mini"


@pytest.mark.asyncio
async def test_feedback_relevance_returns_top_k_examples_scored_by_match(
    session_factory: async_sessionmaker[AsyncSession],
) -> None:
    repo = FeedbackRepo(session_factory)

    seeded: list[FeedbackRecord] = []
    for i in range(8):
        record = await _seed(
            repo,
            feedback_id=f"fb-cryo-{i:02d}",
            domain_tag=DomainTag.CELL_BIOLOGY_CRYOPRESERVATION,
            after=f"Sigma-Aldrich trehalose lot-{i:02d}",
        )
        seeded.append(record)
        await asyncio.sleep(0.001)

    # The agent labels candidates positionally as "cand-000".."cand-007"
    # (most-recent first, matching `find_relevant`'s DESC ordering).
    relevance_items = [
        RelevanceItem(feedback_id=f"cand-{i:03d}", score=0.95 - i * 0.10)
        for i in range(len(seeded))
    ]
    openai = FakeOpenAIClient(
        parsed_responses=[
            _domain_response(DomainTag.CELL_BIOLOGY_CRYOPRESERVATION),
            _relevance_response(relevance_items),
        ],
    )

    agent = FeedbackRelevanceAgent(openai=openai, settings=_settings())
    examples = await agent.run(
        hypothesis="Trehalose vs sucrose cryopreservation of HeLa cells.",
        repo=repo,
        request_id="req-rerank-1",
    )

    assert len(examples) == 5
    scores = [ex.relevance_score for ex in examples]
    assert scores == sorted(scores, reverse=True)
    assert scores[0] == pytest.approx(0.95)


@pytest.mark.asyncio
async def test_feedback_relevance_returns_empty_list_when_no_matches(
    session_factory: async_sessionmaker[AsyncSession],
) -> None:
    repo = FeedbackRepo(session_factory)

    await _seed(
        repo,
        feedback_id="fb-cryo-only",
        domain_tag=DomainTag.CELL_BIOLOGY_CRYOPRESERVATION,
    )

    openai = FakeOpenAIClient(
        parsed_responses=[
            _domain_response(DomainTag.MICROBIOME_MOUSE_MODEL),
        ],
    )

    agent = FeedbackRelevanceAgent(openai=openai, settings=_settings())
    examples = await agent.run(
        hypothesis="L. rhamnosus GG colonisation in C57BL/6 mice.",
        repo=repo,
        request_id="req-empty-1",
    )

    assert examples == []
    assert len(openai.calls) == 1, "Rerank call must be skipped when repo returns nothing"


@pytest.mark.asyncio
async def test_feedback_relevance_emits_structured_log_line_with_required_keys(
    session_factory: async_sessionmaker[AsyncSession],
    caplog: pytest.LogCaptureFixture,
) -> None:
    configure_logging()
    caplog.set_level(logging.INFO, logger="agent")

    repo = FeedbackRepo(session_factory)
    record = await _seed(
        repo,
        feedback_id="fb-log-001",
        domain_tag=DomainTag.CELL_BIOLOGY_CRYOPRESERVATION,
    )

    openai = FakeOpenAIClient(
        parsed_responses=[
            _domain_response(DomainTag.CELL_BIOLOGY_CRYOPRESERVATION),
            _relevance_response([RelevanceItem(feedback_id="cand-000", score=0.9)]),
        ],
    )

    agent = FeedbackRelevanceAgent(openai=openai, settings=_settings())
    examples = await agent.run(
        hypothesis="Trehalose vs sucrose for HeLa cryopreservation.",
        repo=repo,
        request_id="req-log-001",
    )
    # Use `record` to silence the unused-name complaint in mypy.
    assert record.feedback_id == "fb-log-001"
    assert len(examples) == 1

    log_lines = [json.loads(rec.message) for rec in caplog.records if rec.name == "agent"]
    feedback_lines = [line for line in log_lines if line.get("agent") == "feedback_relevance"]
    assert len(feedback_lines) >= 1
    line = feedback_lines[-1]
    for key in (
        "agent",
        "model",
        "prompt_hash",
        "prompt_tokens",
        "completion_tokens",
        "latency_ms",
        "verified_count",
        "tier_0_drops",
        "request_id",
    ):
        assert key in line, f"missing required key in feedback_relevance log line: {key}"
    assert line["agent"] == "feedback_relevance"
    assert line["model"] == "gpt-4.1-mini"
    assert line["request_id"] == "req-log-001"


@pytest.mark.asyncio
async def test_feedback_relevance_role_string_passed_as_system_message(
    session_factory: async_sessionmaker[AsyncSession],
) -> None:
    """The role file content must flow as `system`; user content as `user`."""

    repo = FeedbackRepo(session_factory)
    openai = FakeOpenAIClient(
        parsed_responses=[
            _domain_response(DomainTag.OTHER),
        ],
    )

    agent = FeedbackRelevanceAgent(openai=openai, settings=_settings())
    await agent.run(
        hypothesis="Some unusual hypothesis.",
        repo=repo,
        request_id="req-role-1",
    )

    domain_call = openai.calls[0]
    messages: list[ChatMessage] = domain_call["messages"]
    assert messages[0].role == "system"
    assert "corrections librarian" in messages[0].content
    assert messages[1].role == "user"
    assert "Some unusual hypothesis." in messages[1].content
