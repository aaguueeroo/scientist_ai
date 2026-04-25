"""Step 45 — Feedback-loop end-to-end influence test.

Round-trip integration test that:

1. Submits a `POST /feedback` correction for the trehalose hypothesis
   (vendor `before="acme"` → `after="Sigma-Aldrich trehalose lot-XYZ"`).
2. Calls `POST /generate-plan` with a closely-related hypothesis.
3. Asserts the resulting plan visibly reflects the prior correction
   (the corrected vendor appears; the `before` value does not).

The fake OpenAI client used here is *few-shot aware*: when Agent 3 is
asked to emit an `ExperimentPlan`, the fake inspects the `user` message
it receives. If the corrected `after` value is present in that message
(meaning Agent 2 retrieved the seeded feedback row and Agent 3 was
shown it), the fake returns a plan whose first material vendor matches
the correction. Otherwise it returns a plan with the uncorrected
vendor. This is exactly the "fake clients whose canned plan responses
depend on the few-shots passed in" contract from the plan.

Uses no real network: OpenAI, Tavily, and the citation/catalog
resolvers are all replaced via `monkeypatch` of the `app.api.deps`
factory functions; storage is an in-memory SQLite engine.
"""

# Pydantic v2 coerces plain string URLs into `HttpUrl` at validation time,
# but the pydantic mypy plugin synthesises strict `__init__` signatures that
# reject `str`. Test fixtures here pass literal URLs as `str`; this
# file-level directive silences the resulting `[arg-type]` false positives.
# mypy: disable-error-code="arg-type"

from __future__ import annotations

from collections.abc import AsyncIterator
from typing import Any

import pytest
import pytest_asyncio
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import create_async_engine

from app.agents.feedback_relevance import (
    DomainTagClaim,
    RelevanceClaim,
    RelevanceItem,
)
from app.agents.literature_qc import NoveltyClaim, ReferenceClaim
from app.api import deps as api_deps
from app.clients.openai_client import (
    ChatMessage,
    ChatResult,
    FakeOpenAIClient,
    ParsedResult,
    T,
    TokenUsage,
)
from app.clients.tavily_client import (
    FakeTavilyClient,
    TavilyHit,
    TavilySearchResult,
)
from app.schemas.experiment_plan import (
    ExperimentPlan,
    GroundingSummary,
    Material,
    ProtocolStep,
    ValidationPlan,
)
from app.schemas.feedback import DomainTag
from app.schemas.literature_qc import (
    NoveltyLabel,
    Reference,
    SourceTier,
)
from app.storage import db as storage_db
from app.verification.catalog_resolver import AbstractCatalogResolver
from app.verification.citation_resolver import CitationOutcome, FakeCitationResolver

NATURE_URL = "https://www.nature.com/articles/abc"
CORRECTED_VENDOR = "Sigma-Aldrich trehalose lot-XYZ"
UNCORRECTED_VENDOR = "acme"


class _PassthroughCatalogResolver(AbstractCatalogResolver):
    """Marks any material verified, preserving its original vendor.

    The standard `FakeCatalogResolver` swaps the material for a canned
    outcome keyed by SKU, which would defeat the test's purpose: we
    need the final plan vendor to faithfully reflect *what Agent 3
    emitted*, so that the only path from the seeded correction to the
    response runs through the few-shot retrieval.
    """

    async def resolve(self, material: Material) -> Material:
        if material.vendor and "sigma" in material.vendor.lower():
            url = "https://www.sigmaaldrich.com/US/en/product/sigma/SKU"
        else:
            url = "https://www.thermofisher.com/order/catalog/product/SKU"
        return material.model_copy(
            update={
                "verified": True,
                "verification_url": url,
                "confidence": "high",
            }
        )


def _trehalose_plan(*, vendor: str) -> ExperimentPlan:
    nature_ref = Reference(
        title="Nature paper",
        url=NATURE_URL,
        why_relevant="Direct prior art.",
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    )
    return ExperimentPlan(
        plan_id="plan-loop-001",
        hypothesis="Trehalose preserves HeLa viability better than sucrose at -80C.",
        novelty=NoveltyLabel.SIMILAR_WORK_EXISTS,
        references=[nature_ref],
        protocol=[
            ProtocolStep(
                order=1,
                technique="Cell culture",
                source_url=NATURE_URL,
                tier=SourceTier.TIER_1_PEER_REVIEWED,
            )
        ],
        materials=[
            Material(
                reagent="Trehalose dihydrate",
                vendor=vendor,
                sku="T9531",
                tier=SourceTier.TIER_1_PEER_REVIEWED,
            ),
            Material(
                reagent="DMEM cell-culture medium",
                vendor="Thermo Fisher",
                sku="11965092",
                tier=SourceTier.TIER_1_PEER_REVIEWED,
            ),
        ],
        validation=ValidationPlan(
            success_metrics=["viability >= 80%"],
            failure_metrics=["membrane integrity drop >= 20%"],
        ),
        grounding_summary=GroundingSummary(verified_count=0, unverified_count=1),
    )


class FewShotAwareFakeOpenAIClient(FakeOpenAIClient):
    """Fake whose `ExperimentPlan` response depends on the user message.

    This is the explicit-contract test for the feedback loop: the canned
    plan returned by Agent 3 differs based on whether the seeded
    correction is visible in the user-content the orchestrator built.
    All other parse/chat traffic continues to consume the queued
    canned responses set up at construction time.
    """

    def __init__(
        self,
        *,
        chat_responses: list[ChatResult | BaseException] | None = None,
        parsed_responses: list[ParsedResult[Any] | BaseException] | None = None,
        corrected_marker: str,
    ) -> None:
        super().__init__(chat_responses=chat_responses, parsed_responses=parsed_responses)
        self._corrected_marker = corrected_marker
        self.experiment_plan_calls: list[dict[str, Any]] = []

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
        if response_format is ExperimentPlan:
            user_content = "\n".join(m.content for m in messages if m.role == "user")
            saw_correction = self._corrected_marker in user_content
            self.experiment_plan_calls.append(
                {
                    "saw_correction": saw_correction,
                    "user_content": user_content,
                }
            )
            vendor = CORRECTED_VENDOR if saw_correction else UNCORRECTED_VENDOR
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
            usage = TokenUsage(prompt_tokens=200, completion_tokens=400)
            if self.cost_tracker is not None:
                self.cost_tracker.record(model=model, usage=usage)
            plan = _trehalose_plan(vendor=vendor)
            assert isinstance(plan, response_format)
            return ParsedResult(parsed=plan, usage=usage, model=model)
        return await super().parse(
            model=model,
            messages=messages,
            response_format=response_format,
            temperature=temperature,
            seed=seed,
            max_tokens=max_tokens,
        )


def _domain(tag: DomainTag) -> ParsedResult[DomainTagClaim]:
    return ParsedResult(
        parsed=DomainTagClaim(domain_tag=tag),
        usage=TokenUsage(prompt_tokens=20, completion_tokens=4),
        model="gpt-4.1-mini",
    )


def _rerank(items: list[RelevanceItem]) -> ParsedResult[RelevanceClaim]:
    return ParsedResult(
        parsed=RelevanceClaim(items=items),
        usage=TokenUsage(prompt_tokens=80, completion_tokens=40),
        model="gpt-4.1-mini",
    )


def _qc_claim(novelty: NoveltyLabel) -> ParsedResult[NoveltyClaim]:
    return ParsedResult(
        parsed=NoveltyClaim(
            novelty=novelty,
            references=[
                ReferenceClaim(
                    title="Nature paper",
                    url=NATURE_URL,
                    why_relevant="Direct prior art.",
                )
            ],
            confidence=0.85,
        ),
        usage=TokenUsage(prompt_tokens=120, completion_tokens=80),
        model="gpt-4.1-mini",
    )


def _keyword_chat(content: str = "trehalose cryopreservation HeLa") -> ChatResult:
    return ChatResult(
        content=content,
        usage=TokenUsage(prompt_tokens=20, completion_tokens=10),
        model="gpt-4.1-mini",
    )


def _verified(ref: Reference) -> CitationOutcome:
    return CitationOutcome(
        reference=ref.model_copy(
            update={"verified": True, "verification_url": ref.url, "confidence": "high"}
        ),
        tier_0_drop=False,
    )


@pytest_asyncio.fixture
async def loop_app(
    monkeypatch: pytest.MonkeyPatch,
) -> AsyncIterator[tuple[FastAPI, FewShotAwareFakeOpenAIClient]]:
    """Build a fully-wired FastAPI app for the feedback-loop test."""

    from app.main import create_app

    openai = FewShotAwareFakeOpenAIClient(
        chat_responses=[_keyword_chat()],
        parsed_responses=[
            _qc_claim(NoveltyLabel.SIMILAR_WORK_EXISTS),
            _domain(DomainTag.CELL_BIOLOGY_CRYOPRESERVATION),
            _rerank([RelevanceItem(feedback_id="cand-000", score=0.95)]),
        ],
        corrected_marker=CORRECTED_VENDOR,
    )

    tavily = FakeTavilyClient(
        responses=[
            TavilySearchResult(
                query="verbatim",
                results=[
                    TavilyHit(
                        url=NATURE_URL,
                        title="Nature paper",
                        snippet="...",
                        score=0.9,
                    ),
                ],
            ),
            TavilySearchResult(query="keywords", results=[]),
        ]
    )

    nature_ref = Reference(
        title="Nature paper",
        url=NATURE_URL,
        why_relevant="Direct prior art.",
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    )
    citation_resolver = FakeCitationResolver(outcomes={NATURE_URL: _verified(nature_ref)})

    catalog_resolver = _PassthroughCatalogResolver()

    monkeypatch.setattr(api_deps, "build_openai_client", lambda settings: openai)
    monkeypatch.setattr(api_deps, "build_tavily_client", lambda settings, source_tiers: tavily)
    monkeypatch.setattr(
        api_deps,
        "build_citation_resolver",
        lambda source_tiers: citation_resolver,
    )
    monkeypatch.setattr(
        api_deps,
        "build_catalog_resolver",
        lambda source_tiers: catalog_resolver,
    )
    monkeypatch.setattr(
        storage_db,
        "create_engine",
        lambda settings: create_async_engine("sqlite+aiosqlite:///:memory:", future=True),
    )

    app = create_app()
    async with app.router.lifespan_context(app):
        yield app, openai


@pytest.mark.asyncio
async def test_feedback_loop_correction_visibly_influences_next_plan(
    loop_app: tuple[FastAPI, FewShotAwareFakeOpenAIClient],
) -> None:
    app, openai = loop_app
    transport = ASGITransport(app=app, raise_app_exceptions=False)

    async with AsyncClient(transport=transport, base_url="http://test") as client:
        feedback_response = await client.post(
            "/feedback",
            json={
                "plan_id": "plan-prev-001",
                "domain_tag": DomainTag.CELL_BIOLOGY_CRYOPRESERVATION.value,
                "corrected_field": "materials[0].vendor",
                "before": UNCORRECTED_VENDOR,
                "after": CORRECTED_VENDOR,
                "reason": "standard supplier per published protocol",
            },
        )
        assert feedback_response.status_code == 200, feedback_response.text

        plan_response = await client.post(
            "/generate-plan",
            json={
                "hypothesis": (
                    "Trehalose preserves HeLa cell viability better than sucrose "
                    "during -80C cryopreservation."
                )
            },
        )

    assert plan_response.status_code == 200, plan_response.text
    body = plan_response.json()
    assert body["plan"] is not None, "Continue branch must produce a plan."

    materials = body["plan"]["materials"]
    vendors: list[str] = [m["vendor"] for m in materials]
    assert any(CORRECTED_VENDOR == v for v in vendors), (
        f"The corrected vendor must appear in the new plan; got vendors={vendors}"
    )
    assert UNCORRECTED_VENDOR not in vendors, (
        f"The pre-correction vendor must not appear; got vendors={vendors}"
    )

    assert openai.experiment_plan_calls, "Agent 3 must have been called"
    last_plan_call = openai.experiment_plan_calls[-1]
    assert last_plan_call["saw_correction"], (
        "Agent 3's user message must include the corrected vendor "
        "(few-shot retrieval did not surface the seeded feedback row)."
    )

    parse_calls = [c for c in openai.calls if c["kind"] == "parse"]
    rfm = [c["response_format"].__name__ for c in parse_calls]
    assert "RelevanceClaim" in rfm, "Agent 2's rerank step must run on the full path."
