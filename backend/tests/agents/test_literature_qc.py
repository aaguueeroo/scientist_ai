"""Tests for the literature-QC schema (Step 13) and runtime agent (Step 23)."""

# pydantic v2 coerces plain string URLs into `HttpUrl` at validation time,
# but the pydantic mypy plugin generates strict `__init__` signatures that
# reject `str`. Test fixtures here pass literal URLs as `str`; this
# file-level directive silences the resulting `arg-type` false positives.
# mypy: disable-error-code="arg-type"

from __future__ import annotations

import json
import logging

import pytest
from pydantic import ValidationError

from app.agents.literature_qc import LiteratureQCAgent, NoveltyClaim, ReferenceClaim
from app.clients.openai_client import (
    ChatResult,
    FakeOpenAIClient,
    ParsedResult,
    TokenUsage,
)
from app.clients.tavily_client import FakeTavilyClient, TavilyHit, TavilySearchResult
from app.config.source_tiers import load_source_tiers
from app.observability.logging import configure_logging
from app.schemas.literature_qc import (
    LiteratureQCResult,
    NoveltyLabel,
    Reference,
    SourceTier,
)
from app.verification.citation_resolver import CitationOutcome, FakeCitationResolver


def test_source_tier_enum_has_four_values_including_tier_0() -> None:
    values = {member.value for member in SourceTier}
    assert values == {
        "tier_1_peer_reviewed",
        "tier_2_preprint_or_community",
        "tier_3_general_web",
        "tier_0_forbidden",
    }


def test_novelty_label_enum_has_three_values() -> None:
    values = {member.value for member in NoveltyLabel}
    assert values == {"not_found", "similar_work_exists", "exact_match"}


def test_reference_requires_tier_and_defaults_unverified() -> None:
    ref = Reference(
        title="A real paper",
        url="https://www.nature.com/articles/abc",
        why_relevant="Directly motivates the hypothesis.",
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    )
    assert ref.verified is False
    assert ref.confidence == "low"
    assert ref.verification_url is None

    with pytest.raises(ValidationError):
        Reference(  # type: ignore[call-arg]
            title="Missing tier",
            url="https://www.nature.com/articles/xyz",
            why_relevant="No tier supplied.",
        )


def test_reference_serializes_verification_url_when_present() -> None:
    ref = Reference(
        title="Verified paper",
        url="https://www.nature.com/articles/abc",
        why_relevant="Verified via DOI resolver.",
        tier=SourceTier.TIER_1_PEER_REVIEWED,
        verified=True,
        verification_url="https://doi.org/10.1038/s41586-020-2649-2",
        confidence="high",
    )
    dumped = ref.model_dump(mode="json")
    assert dumped["verification_url"] == "https://doi.org/10.1038/s41586-020-2649-2"
    assert dumped["verified"] is True


def test_literature_qc_result_caps_references_at_three() -> None:
    refs = [
        Reference(
            title=f"Paper {i}",
            url=f"https://www.nature.com/articles/{i}",
            why_relevant="Relevant.",
            tier=SourceTier.TIER_1_PEER_REVIEWED,
        )
        for i in range(4)
    ]
    with pytest.raises(ValidationError):
        LiteratureQCResult(novelty=NoveltyLabel.SIMILAR_WORK_EXISTS, references=refs)

    ok = LiteratureQCResult(
        novelty=NoveltyLabel.SIMILAR_WORK_EXISTS,
        references=refs[:3],
    )
    assert len(ok.references) == 3
    assert ok.tier_0_drops == 0


def _keyword_chat(content: str = "trehalose cryopreservation HeLa") -> ChatResult:
    return ChatResult(
        content=content,
        usage=TokenUsage(prompt_tokens=20, completion_tokens=10),
        model="gpt-4.1-mini",
    )


def _claim(refs: list[ReferenceClaim], confidence: float = 0.9) -> ParsedResult[NoveltyClaim]:
    return ParsedResult(
        parsed=NoveltyClaim(
            novelty=NoveltyLabel.SIMILAR_WORK_EXISTS,
            references=refs,
            confidence=confidence,
        ),
        usage=TokenUsage(prompt_tokens=120, completion_tokens=80),
        model="gpt-4.1-mini",
    )


def _verified(ref: Reference) -> CitationOutcome:
    return CitationOutcome(
        reference=ref.model_copy(
            update={
                "verified": True,
                "verification_url": ref.url,
                "confidence": "high",
            }
        ),
        tier_0_drop=False,
    )


def _unverified() -> CitationOutcome:
    return CitationOutcome(reference=None, tier_0_drop=False)


@pytest.mark.asyncio
async def test_literature_qc_returns_result_with_correct_tier_per_reference() -> None:
    nature_url = "https://www.nature.com/articles/abc"
    biorxiv_url = "https://www.biorxiv.org/content/10.1101/2024.01.01"

    tavily = FakeTavilyClient(
        responses=[
            TavilySearchResult(
                query="verbatim",
                results=[
                    TavilyHit(url=nature_url, title="Nature paper", snippet="...", score=0.9),
                ],
            ),
            TavilySearchResult(
                query="keywords",
                results=[
                    TavilyHit(url=biorxiv_url, title="Preprint paper", snippet="...", score=0.8),
                ],
            ),
        ]
    )
    openai = FakeOpenAIClient(
        chat_responses=[_keyword_chat("alpha beta gamma")],
        parsed_responses=[
            _claim(
                [
                    ReferenceClaim(
                        title="Nature paper",
                        url=nature_url,
                        why_relevant="Directly motivates the hypothesis.",
                    ),
                    ReferenceClaim(
                        title="Preprint paper",
                        url=biorxiv_url,
                        why_relevant="Closest preprint match.",
                    ),
                ]
            )
        ],
    )
    nature_ref = Reference(
        title="Nature paper",
        url=nature_url,
        why_relevant="Directly motivates the hypothesis.",
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    )
    biorxiv_ref = Reference(
        title="Preprint paper",
        url=biorxiv_url,
        why_relevant="Closest preprint match.",
        tier=SourceTier.TIER_2_PREPRINT_OR_COMMUNITY,
    )
    resolver = FakeCitationResolver(
        outcomes={
            nature_url: _verified(nature_ref),
            biorxiv_url: _verified(biorxiv_ref),
        }
    )
    agent = LiteratureQCAgent(
        openai=openai,
        tavily=tavily,
        citation_resolver=resolver,
        source_tiers=load_source_tiers(),
    )
    result = await agent.run(
        hypothesis="Trehalose preserves HeLa viability better than sucrose at -80C.",
        request_id="r-1",
    )
    tiers = {str(r.url): r.tier for r in result.references}
    assert tiers[nature_url] == SourceTier.TIER_1_PEER_REVIEWED
    assert tiers[biorxiv_url] == SourceTier.TIER_2_PREPRINT_OR_COMMUNITY
    assert result.tier_0_drops == 0


@pytest.mark.asyncio
async def test_literature_qc_dropped_tier_0_hits_increment_tier_0_drops() -> None:
    nature_url = "https://www.nature.com/articles/abc"
    fb_url = "https://www.facebook.com/share/123"

    tavily = FakeTavilyClient(
        responses=[
            TavilySearchResult(
                query="verbatim",
                results=[
                    TavilyHit(url=fb_url, title="Facebook post", snippet="...", score=0.7),
                    TavilyHit(url=nature_url, title="Nature paper", snippet="...", score=0.9),
                ],
            ),
            TavilySearchResult(query="keywords", results=[]),
        ]
    )
    openai = FakeOpenAIClient(
        chat_responses=[_keyword_chat()],
        parsed_responses=[
            _claim(
                [
                    ReferenceClaim(
                        title="Nature paper",
                        url=nature_url,
                        why_relevant="Real Nature paper.",
                    )
                ]
            )
        ],
    )
    nature_ref = Reference(
        title="Nature paper",
        url=nature_url,
        why_relevant="Real Nature paper.",
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    )
    resolver = FakeCitationResolver(outcomes={nature_url: _verified(nature_ref)})
    agent = LiteratureQCAgent(
        openai=openai,
        tavily=tavily,
        citation_resolver=resolver,
        source_tiers=load_source_tiers(),
    )
    result = await agent.run(hypothesis="x" * 20, request_id="r-2")
    assert result.tier_0_drops == 1
    parse_call = next(c for c in openai.calls if c["kind"] == "parse")
    payload = parse_call["messages"][1].content
    assert "facebook.com" not in payload


@pytest.mark.asyncio
async def test_literature_qc_unverified_references_are_dropped() -> None:
    good_url = "https://www.nature.com/articles/good"
    bad_url = "https://www.nature.com/articles/bad"
    tavily = FakeTavilyClient(
        responses=[
            TavilySearchResult(
                query="verbatim",
                results=[
                    TavilyHit(url=good_url, title="Good", snippet="...", score=0.9),
                    TavilyHit(url=bad_url, title="Bad", snippet="...", score=0.5),
                ],
            ),
            TavilySearchResult(query="keywords", results=[]),
        ]
    )
    openai = FakeOpenAIClient(
        chat_responses=[_keyword_chat()],
        parsed_responses=[
            _claim(
                [
                    ReferenceClaim(title="Good", url=good_url, why_relevant="Resolves."),
                    ReferenceClaim(title="Bad", url=bad_url, why_relevant="Does not."),
                ]
            )
        ],
    )
    good_ref = Reference(
        title="Good",
        url=good_url,
        why_relevant="Resolves.",
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    )
    resolver = FakeCitationResolver(
        outcomes={good_url: _verified(good_ref), bad_url: _unverified()},
    )
    agent = LiteratureQCAgent(
        openai=openai,
        tavily=tavily,
        citation_resolver=resolver,
        source_tiers=load_source_tiers(),
    )
    result = await agent.run(hypothesis="x" * 20, request_id="r-3")
    assert len(result.references) == 1
    assert str(result.references[0].url) == good_url


@pytest.mark.asyncio
async def test_literature_qc_similarity_suggestion_when_no_verified_refs() -> None:
    """When the resolver returns nothing, surface one Tavily hit as unverified similar."""

    nature_url = "https://www.nature.com/articles/fallback-1"
    tavily = FakeTavilyClient(
        responses=[
            TavilySearchResult(
                query="verbatim",
                results=[
                    TavilyHit(
                        url=nature_url,
                        title="Tavily title",
                        snippet="A snippet for context.",
                        score=0.55,
                    ),
                ],
            ),
            TavilySearchResult(query="keywords", results=[]),
        ]
    )
    openai = FakeOpenAIClient(
        chat_responses=[_keyword_chat()],
        parsed_responses=[
            _claim(
                [
                    ReferenceClaim(
                        title="LLM title",
                        url=nature_url,
                        why_relevant="Claim that will not verify.",
                    ),
                ]
            )
        ],
    )
    resolver = FakeCitationResolver(outcomes={nature_url: _unverified()})
    agent = LiteratureQCAgent(
        openai=openai,
        tavily=tavily,
        citation_resolver=resolver,
        source_tiers=load_source_tiers(),
    )
    result = await agent.run(hypothesis="x" * 20, request_id="r-sim-1")
    assert result.references == []
    assert result.similarity_suggestion is not None
    s = result.similarity_suggestion
    assert str(s.url) == nature_url
    assert s.is_similarity_suggestion is True
    assert s.verified is False
    assert s.confidence == "low"


@pytest.mark.asyncio
async def test_literature_qc_tavily_score_promotes_to_verified_when_resolver_fails() -> None:
    """Tavily relevance > 0.6 counts as verified even if the HTTP resolver does not verify."""

    u = "https://www.nature.com/articles/tavily-075"
    tavily = FakeTavilyClient(
        responses=[
            TavilySearchResult(
                query="verbatim",
                results=[TavilyHit(url=u, title="Paper", snippet="S", score=0.75)],
            ),
            TavilySearchResult(query="keywords", results=[]),
        ]
    )
    openai = FakeOpenAIClient(
        chat_responses=[_keyword_chat()],
        parsed_responses=[_claim([ReferenceClaim(title="Paper", url=u, why_relevant="R.")])],
    )
    agent = LiteratureQCAgent(
        openai=openai,
        tavily=tavily,
        citation_resolver=FakeCitationResolver(outcomes={u: _unverified()}),
        source_tiers=load_source_tiers(),
    )
    result = await agent.run(hypothesis="x" * 20, request_id="r-tv-1")
    assert len(result.references) == 1
    assert str(result.references[0].url) == u
    assert result.references[0].verified is True
    assert result.references[0].is_similarity_suggestion is False
    assert result.similarity_suggestion is None


@pytest.mark.asyncio
async def test_literature_qc_web_wide_last_resort_when_domain_search_empty() -> None:
    """Unrestricted Tavily run supplies one unverified ref when the allowlist returns nothing."""

    wide_url = "https://www.nature.com/articles/web-wide-fallback"
    tavily = FakeTavilyClient(
        responses=[
            TavilySearchResult(query="verbatim", results=[]),
            TavilySearchResult(query="keywords", results=[]),
        ],
        web_wide_responses=[
            TavilySearchResult(
                query="keywords",
                results=[
                    TavilyHit(
                        url=wide_url,
                        title="Web-wide hit",
                        snippet="Possibly related study.",
                        score=0.55,
                    )
                ],
            )
        ],
    )
    openai = FakeOpenAIClient(
        chat_responses=[_keyword_chat("trehalose HeLa cryo")],
        parsed_responses=[
            _claim(
                [],
                confidence=0.6,
            )
        ],
    )
    agent = LiteratureQCAgent(
        openai=openai,
        tavily=tavily,
        citation_resolver=FakeCitationResolver(outcomes={}),
        source_tiers=load_source_tiers(),
    )
    result = await agent.run(hypothesis="x" * 20, request_id="r-web-1")
    assert result.references == []
    assert result.similarity_suggestion is not None
    assert str(result.similarity_suggestion.url) == wide_url
    assert any(c.get("kind") == "search_web_wide" for c in tavily.calls)


@pytest.mark.asyncio
async def test_literature_qc_emits_structured_log_line_with_required_keys(
    caplog: pytest.LogCaptureFixture,
) -> None:
    configure_logging()
    nature_url = "https://www.nature.com/articles/abc"
    tavily = FakeTavilyClient(
        responses=[
            TavilySearchResult(
                query="verbatim",
                results=[
                    TavilyHit(url=nature_url, title="N", snippet="...", score=0.9),
                ],
            ),
            TavilySearchResult(query="keywords", results=[]),
        ]
    )
    openai = FakeOpenAIClient(
        chat_responses=[_keyword_chat()],
        parsed_responses=[
            _claim(
                [
                    ReferenceClaim(title="N", url=nature_url, why_relevant="Solid."),
                ]
            )
        ],
    )
    nature_ref = Reference(
        title="N",
        url=nature_url,
        why_relevant="Solid.",
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    )
    resolver = FakeCitationResolver(outcomes={nature_url: _verified(nature_ref)})
    agent = LiteratureQCAgent(
        openai=openai,
        tavily=tavily,
        citation_resolver=resolver,
        source_tiers=load_source_tiers(),
    )

    with caplog.at_level(logging.INFO, logger="agent"):
        await agent.run(hypothesis="x" * 20, request_id="req-log-1")

    line = next(rec for rec in caplog.records if "agent.call.complete" in rec.getMessage())
    payload = json.loads(line.getMessage())
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
        assert key in payload, f"missing key: {key}"
    assert payload["agent"] == "literature_qc"
    assert payload["model"] == "gpt-4.1-mini"
    assert payload["request_id"] == "req-log-1"
    assert payload["verified_count"] == 1


@pytest.mark.asyncio
async def test_literature_qc_deduplicates_identical_llm_claims() -> None:
    """The model may repeat the same source; we keep one verified ref."""

    url = "https://www.nature.com/articles/dedupe-claim"
    tavily = FakeTavilyClient(
        responses=[
            TavilySearchResult(
                query="verbatim",
                results=[TavilyHit(url=url, title="One", snippet=".", score=0.9)],
            ),
            TavilySearchResult(query="keywords", results=[]),
        ]
    )
    openai = FakeOpenAIClient(
        chat_responses=[_keyword_chat()],
        parsed_responses=[
            _claim(
                [
                    ReferenceClaim(title="A", url=url, why_relevant="first"),
                    ReferenceClaim(
                        title="A again",
                        url=url,
                        why_relevant="second row same URL",
                    ),
                ]
            )
        ],
    )
    res_ref = Reference(
        title="A",
        url=url,
        why_relevant="first",
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    )
    resolver = FakeCitationResolver(outcomes={url: _verified(res_ref)})
    agent = LiteratureQCAgent(
        openai=openai,
        tavily=tavily,
        citation_resolver=resolver,
        source_tiers=load_source_tiers(),
    )
    result = await agent.run(hypothesis="x" * 20, request_id="r-dedupe-1")
    assert len(result.references) == 1
    assert str(result.references[0].url) == url


@pytest.mark.asyncio
async def test_literature_qc_deduplicates_doi_url_variants() -> None:
    """https://doi.org/... and http://dx.doi.org/... are one work."""

    # DOI prefix must match tier_1_doi_prefixes (e.g. 10.1016) for doi.org URLs.
    slug = "10.1016/j.dedupe.2024.01.001"
    u1 = f"https://doi.org/{slug}"
    u2 = f"http://dx.doi.org/{slug}"
    tavily = FakeTavilyClient(
        responses=[
            TavilySearchResult(
                query="verbatim",
                results=[TavilyHit(url=u1, title="D", snippet=".", score=0.9)],
            ),
            TavilySearchResult(query="keywords", results=[]),
        ]
    )
    openai = FakeOpenAIClient(
        chat_responses=[_keyword_chat()],
        parsed_responses=[
            _claim(
                [
                    ReferenceClaim(
                        title="One",
                        url=u1,
                        why_relevant="a",
                        doi=slug,
                    ),
                    ReferenceClaim(
                        title="Two",
                        url=u2,
                        why_relevant="b",
                    ),
                ]
            )
        ],
    )
    r1 = Reference(
        title="One",
        url=u1,
        doi=slug,
        why_relevant="a",
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    )
    resolver = FakeCitationResolver(outcomes={u1: _verified(r1)})
    agent = LiteratureQCAgent(
        openai=openai,
        tavily=tavily,
        citation_resolver=resolver,
        source_tiers=load_source_tiers(),
    )
    result = await agent.run(hypothesis="x" * 20, request_id="r-dedupe-2")
    assert len(result.references) == 1
    assert result.references[0].doi == slug


@pytest.mark.asyncio
async def test_literature_qc_deduplicates_post_resolve_by_doi() -> None:
    """Different claim URLs with the same DOI on verified refs return once."""

    u1 = "https://www.nature.com/articles/post-dedupe-one"
    u2 = "https://www.nature.com/articles/post-dedupe-two"
    d = "10.1016/j.postresolve.2024.01.001"
    tavily = FakeTavilyClient(
        responses=[
            TavilySearchResult(
                query="verbatim",
                results=[
                    TavilyHit(url=u1, title="P1", snippet=".", score=0.9),
                    TavilyHit(url=u2, title="P2", snippet=".", score=0.88),
                ],
            ),
            TavilySearchResult(query="keywords", results=[]),
        ]
    )
    r1 = Reference(
        title="P1",
        url=u1,
        doi=d,
        why_relevant="a",
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    )
    r2 = Reference(
        title="P2",
        url=u2,
        doi=d,
        why_relevant="b",
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    )
    openai = FakeOpenAIClient(
        chat_responses=[_keyword_chat()],
        parsed_responses=[
            _claim(
                [
                    ReferenceClaim(
                        title="P1", url=u1, why_relevant="a", doi=None
                    ),
                    ReferenceClaim(
                        title="P2", url=u2, why_relevant="b", doi=None
                    ),
                ]
            )
        ],
    )
    resolver = FakeCitationResolver(
        outcomes={u1: _verified(r1), u2: _verified(r2)}
    )
    agent = LiteratureQCAgent(
        openai=openai,
        tavily=tavily,
        citation_resolver=resolver,
        source_tiers=load_source_tiers(),
    )
    result = await agent.run(hypothesis="x" * 20, request_id="r-dedupe-3")
    assert len(result.references) == 1
    assert result.references[0].doi == d
