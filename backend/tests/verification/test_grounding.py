"""Tests for `app/verification/grounding.py` (Steps 30 + 31)."""

# Pydantic v2 coerces plain string URLs into `HttpUrl` at validation time,
# but the pydantic mypy plugin rejects `str` arguments to `HttpUrl` fields.
# Test fixtures here use literal URLs as `str`; silence the arg-type noise.
# mypy: disable-error-code="arg-type"

from __future__ import annotations

import pytest

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
from app.verification.catalog_resolver import FakeCatalogResolver
from app.verification.citation_resolver import CitationOutcome, FakeCitationResolver
from app.verification.grounding import apply_resolvers

NATURE_URL = "https://www.nature.com/articles/abc"
FAKE_DOI_URL = "https://doi.org/10.9999/FAKE-fake-fake"
FACEBOOK_URL = "https://www.facebook.com/share/abc"


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


def _build_plan(
    *,
    references: list[Reference],
    materials: list[Material],
    protocol: list[ProtocolStep] | None = None,
) -> ExperimentPlan:
    return ExperimentPlan(
        plan_id="plan-grnd",
        hypothesis="Trehalose preserves HeLa viability better than sucrose at -80C.",
        novelty=NoveltyLabel.SIMILAR_WORK_EXISTS,
        references=references,
        protocol=protocol or [],
        materials=materials,
        validation=ValidationPlan(
            success_metrics=["viability >= 80% post-thaw"],
            failure_metrics=["membrane integrity drop >= 20%"],
        ),
        grounding_summary=GroundingSummary(verified_count=0, unverified_count=0),
    )


@pytest.mark.asyncio
async def test_grounding_pipeline_marks_verified_for_resolved_items() -> None:
    nature_ref = Reference(
        title="Trehalose vs sucrose",
        url=NATURE_URL,
        why_relevant="Direct prior art.",
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    )
    trehalose = Material(
        reagent="Trehalose dihydrate",
        vendor="Sigma-Aldrich",
        sku="T9531",
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    )
    plan = _build_plan(references=[nature_ref], materials=[trehalose])

    citation_resolver = FakeCitationResolver(outcomes={NATURE_URL: _verified(nature_ref)})
    catalog_resolver = FakeCatalogResolver(
        outcomes={
            "T9531": trehalose.model_copy(
                update={
                    "verified": True,
                    "verification_url": "https://www.sigmaaldrich.com/US/en/product/sigma/T9531",
                    "confidence": "high",
                }
            )
        }
    )

    grounded = await apply_resolvers(
        plan,
        citation_resolver=citation_resolver,
        catalog_resolver=catalog_resolver,
    )

    assert len(grounded.references) == 1
    assert grounded.references[0].verified is True
    assert grounded.materials[0].verified is True
    assert grounded.grounding_summary.verified_count == 2
    assert grounded.grounding_summary.unverified_count == 0
    assert grounded.grounding_summary.tier_0_drops == 0


@pytest.mark.asyncio
async def test_grounding_pipeline_filters_or_flags_fabricated_reference() -> None:
    real_ref = Reference(
        title="Real paper",
        url=NATURE_URL,
        why_relevant="Real evidence.",
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    )
    fake_ref = Reference(
        title="Totally Made Up Paper",
        url=FAKE_DOI_URL,
        doi="10.9999/FAKE-fake-fake",
        why_relevant="Fabricated.",
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    )
    plan = _build_plan(references=[real_ref, fake_ref], materials=[])

    citation_resolver = FakeCitationResolver(
        outcomes={
            NATURE_URL: _verified(real_ref),
            FAKE_DOI_URL: CitationOutcome(reference=None, tier_0_drop=False),
        }
    )
    catalog_resolver = FakeCatalogResolver(outcomes={})

    grounded = await apply_resolvers(
        plan,
        citation_resolver=citation_resolver,
        catalog_resolver=catalog_resolver,
    )

    refs_by_url = {str(r.url): r for r in grounded.references}
    assert refs_by_url[NATURE_URL].verified is True
    assert FAKE_DOI_URL in refs_by_url
    assert refs_by_url[FAKE_DOI_URL].verified is False
    assert refs_by_url[FAKE_DOI_URL].confidence == "low"
    assert grounded.grounding_summary.verified_count == 1
    assert grounded.grounding_summary.unverified_count == 1


@pytest.mark.asyncio
async def test_grounding_pipeline_filters_or_flags_fabricated_sku() -> None:
    real_mat = Material(
        reagent="Trehalose dihydrate",
        vendor="Sigma-Aldrich",
        sku="T9531",
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    )
    fake_mat = Material(
        reagent="Made up reagent",
        vendor="Sigma-Aldrich",
        sku="SKU-FAKE-NEVER-EXISTED",
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    )
    plan = _build_plan(references=[], materials=[real_mat, fake_mat])

    citation_resolver = FakeCitationResolver(outcomes={})
    catalog_resolver = FakeCatalogResolver(
        outcomes={
            "T9531": real_mat.model_copy(
                update={
                    "verified": True,
                    "verification_url": "https://www.sigmaaldrich.com/US/en/product/sigma/T9531",
                    "confidence": "high",
                }
            ),
        }
    )

    grounded = await apply_resolvers(
        plan,
        citation_resolver=citation_resolver,
        catalog_resolver=catalog_resolver,
    )

    materials_by_sku = {m.sku: m for m in grounded.materials}
    assert materials_by_sku["T9531"].verified is True
    assert materials_by_sku["SKU-FAKE-NEVER-EXISTED"].verified is False
    assert materials_by_sku["SKU-FAKE-NEVER-EXISTED"].confidence == "low"
    assert grounded.grounding_summary.verified_count == 1
    assert grounded.grounding_summary.unverified_count == 1


@pytest.mark.asyncio
async def test_grounding_pipeline_increments_tier_0_drops_for_facebook_url() -> None:
    real_ref = Reference(
        title="Real paper",
        url=NATURE_URL,
        why_relevant="Real evidence.",
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    )
    fb_ref = Reference(
        title="Facebook post",
        url=FACEBOOK_URL,
        why_relevant="Tier-0 forbidden source.",
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    )
    plan = _build_plan(references=[real_ref, fb_ref], materials=[])

    citation_resolver = FakeCitationResolver(
        outcomes={
            NATURE_URL: _verified(real_ref),
            FACEBOOK_URL: CitationOutcome(reference=None, tier_0_drop=True),
        }
    )
    catalog_resolver = FakeCatalogResolver(outcomes={})

    grounded = await apply_resolvers(
        plan,
        citation_resolver=citation_resolver,
        catalog_resolver=catalog_resolver,
    )

    urls = {str(r.url) for r in grounded.references}
    assert FACEBOOK_URL not in urls
    assert grounded.grounding_summary.tier_0_drops == 1
    assert grounded.grounding_summary.verified_count == 1
