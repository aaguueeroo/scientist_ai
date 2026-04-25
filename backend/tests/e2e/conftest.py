"""Shared fixtures for the four e2e hypothesis tests (Steps 47-50)."""

# Pydantic v2 coerces plain string URLs into `HttpUrl` at validation time,
# but the pydantic mypy plugin synthesises strict `__init__` signatures that
# reject `str`. Test fixtures pass literal URLs as `str`; this file-level
# directive silences the resulting `[arg-type]` false positives.
# mypy: disable-error-code="arg-type"

from __future__ import annotations

from collections.abc import AsyncIterator, Sequence
from dataclasses import dataclass

import pytest
import pytest_asyncio
from fastapi import FastAPI
from pydantic import HttpUrl, TypeAdapter
from sqlalchemy.ext.asyncio import create_async_engine

from app.agents.literature_qc import NoveltyClaim, ReferenceClaim
from app.api import deps as api_deps
from app.clients.openai_client import (
    ChatResult,
    FakeOpenAIClient,
    ParsedResult,
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
from app.schemas.literature_qc import (
    NoveltyLabel,
    Reference,
    SourceTier,
)
from app.storage import db as storage_db
from app.verification.catalog_resolver import AbstractCatalogResolver
from app.verification.citation_resolver import CitationOutcome, FakeCitationResolver

_HTTP_URL_ADAPTER = TypeAdapter(HttpUrl)


def _to_http_url(url: str) -> HttpUrl:
    """Validate a string into a real `HttpUrl` instance.

    Pydantic v2 emits a `PydanticSerializationUnexpectedValue` warning when a
    `HttpUrl`-typed field is mutated with a plain string via `model_copy`.
    This helper centralises the coercion so tests/fixtures never trip it.
    """

    return _HTTP_URL_ADAPTER.validate_python(url)


@dataclass(frozen=True)
class HypothesisFixture:
    """Per-hypothesis canned payloads driving the offline e2e."""

    hypothesis: str
    keyword_summary: str
    references: list[Reference]
    plan: ExperimentPlan
    sku_resolutions: dict[str, tuple[str, str]]


class _PassthroughCatalogResolver(AbstractCatalogResolver):
    """Marks a material verified, copying values from a `(vendor, url)` map.

    Production wiring uses the real Sigma-Aldrich/Thermo-Fisher resolver
    (Step 27). Here we want the e2e to be deterministic without making a
    live HTTP request, so the fake records both `verified=True` and a
    realistic `verification_url` for each SKU declared in the fixture.
    """

    def __init__(self, sku_resolutions: dict[str, tuple[str, str]]) -> None:
        self._sku_resolutions = sku_resolutions

    async def resolve(self, material: Material) -> Material:
        if material.sku is None or material.sku not in self._sku_resolutions:
            return material.model_copy(
                update={
                    "verified": False,
                    "verification_url": None,
                    "confidence": "low",
                }
            )
        vendor, url = self._sku_resolutions[material.sku]
        return material.model_copy(
            update={
                "vendor": vendor,
                "verified": True,
                "verification_url": _to_http_url(url),
                "confidence": "high",
            }
        )


def _verified(ref: Reference) -> CitationOutcome:
    return CitationOutcome(
        reference=ref.model_copy(
            update={"verified": True, "verification_url": ref.url, "confidence": "high"}
        ),
        tier_0_drop=False,
    )


def _qc_claim(
    novelty: NoveltyLabel,
    refs: Sequence[Reference],
) -> ParsedResult[NoveltyClaim]:
    return ParsedResult(
        parsed=NoveltyClaim(
            novelty=novelty,
            references=[
                ReferenceClaim(
                    title=ref.title,
                    url=str(ref.url),
                    why_relevant=ref.why_relevant,
                    doi=ref.doi,
                )
                for ref in refs
            ],
            confidence=0.85,
        ),
        usage=TokenUsage(prompt_tokens=120, completion_tokens=80),
        model="gpt-4.1-mini",
    )


def _parsed_plan(plan: ExperimentPlan) -> ParsedResult[ExperimentPlan]:
    return ParsedResult(
        parsed=plan,
        usage=TokenUsage(prompt_tokens=200, completion_tokens=400),
        model="gpt-4.1",
    )


def _keyword_chat(content: str) -> ChatResult:
    return ChatResult(
        content=content,
        usage=TokenUsage(prompt_tokens=20, completion_tokens=10),
        model="gpt-4.1-mini",
    )


def _tavily_responses(refs: Sequence[Reference]) -> list[TavilySearchResult]:
    return [
        TavilySearchResult(
            query="verbatim",
            results=[
                TavilyHit(
                    url=str(ref.url),
                    title=ref.title,
                    snippet=ref.why_relevant,
                    score=0.9,
                )
                for ref in refs
            ],
        ),
        TavilySearchResult(query="keywords", results=[]),
    ]


@pytest_asyncio.fixture
async def e2e_app_factory(monkeypatch: pytest.MonkeyPatch):  # type: ignore[no-untyped-def]
    """Returns a builder that wires up a fully-mocked FastAPI app for one e2e run."""

    async def _build(fixture: HypothesisFixture) -> AsyncIterator[FastAPI]:
        from app.main import create_app

        openai = FakeOpenAIClient(
            chat_responses=[_keyword_chat(fixture.keyword_summary)],
            parsed_responses=[
                _qc_claim(NoveltyLabel.SIMILAR_WORK_EXISTS, fixture.references),
                _parsed_plan(fixture.plan),
            ],
        )
        tavily = FakeTavilyClient(responses=_tavily_responses(fixture.references))
        citation_resolver = FakeCitationResolver(
            outcomes={str(ref.url): _verified(ref) for ref in fixture.references}
        )
        catalog_resolver = _PassthroughCatalogResolver(fixture.sku_resolutions)

        monkeypatch.setattr(api_deps, "build_openai_client", lambda settings: openai)
        monkeypatch.setattr(api_deps, "build_tavily_client", lambda settings, source_tiers: tavily)
        monkeypatch.setattr(
            api_deps, "build_citation_resolver", lambda source_tiers: citation_resolver
        )
        monkeypatch.setattr(
            api_deps, "build_catalog_resolver", lambda source_tiers: catalog_resolver
        )
        monkeypatch.setattr(
            storage_db,
            "create_engine",
            lambda settings: create_async_engine("sqlite+aiosqlite:///:memory:", future=True),
        )

        app = create_app()
        async with app.router.lifespan_context(app):
            yield app

    return _build


def make_protocol_step(
    *,
    order: int,
    technique: str,
    source_url: str,
    description: str = "",
) -> ProtocolStep:
    return ProtocolStep(
        order=order,
        technique=technique,
        description=description,
        source_url=source_url,
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    )


def make_material(
    *,
    reagent: str,
    vendor: str,
    sku: str,
    notes: str | None = None,
) -> Material:
    return Material(
        reagent=reagent,
        vendor=vendor,
        sku=sku,
        notes=notes,
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    )


def make_reference(
    *,
    title: str,
    url: str,
    why_relevant: str,
    doi: str | None = None,
) -> Reference:
    return Reference(
        title=title,
        url=url,
        doi=doi,
        why_relevant=why_relevant,
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    )


def baseline_validation() -> ValidationPlan:
    return ValidationPlan(
        success_metrics=["assay sensitivity within published range"],
        failure_metrics=["coefficient of variation > 20%"],
    )


def baseline_grounding() -> GroundingSummary:
    return GroundingSummary(verified_count=0, unverified_count=0)
