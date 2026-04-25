"""Tests for the citation resolver (Step 22)."""

# Pydantic v2 coerces plain string URLs into `HttpUrl` at validation time,
# but the pydantic mypy plugin rejects `str` arguments to `HttpUrl` fields.
# Fixtures here use literal URLs as `str`; silence the arg-type noise.
# mypy: disable-error-code="arg-type"

from __future__ import annotations

import httpx
import pytest
import respx

from app.config.source_tiers import load_source_tiers
from app.schemas.literature_qc import Reference, SourceTier
from app.verification.citation_resolver import (
    CitationOutcome,
    FakeCitationResolver,
    RealCitationResolver,
)


@pytest.mark.asyncio
@respx.mock
async def test_citation_resolver_real_doi_resolves_with_matching_title() -> None:
    title = (
        "The MIQE guidelines: minimum information for publication "
        "of quantitative real-time PCR experiments"
    )
    doi = "10.1373/clinchem.2008.112797"
    respx.get(f"https://doi.org/{doi}").mock(
        return_value=httpx.Response(
            200,
            html=f"<html><head><title>{title}</title></head><body></body></html>",
        )
    )
    resolver = RealCitationResolver(source_tiers=load_source_tiers())
    ref = Reference(
        title=title,
        url=f"https://doi.org/{doi}",
        doi=doi,
        why_relevant="MIQE checklist source.",
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    )
    out = await resolver.resolve(ref)
    assert isinstance(out, CitationOutcome)
    assert out.tier_0_drop is False
    assert out.reference is not None
    assert out.reference.verified is True
    assert out.reference.verification_url is not None


@pytest.mark.asyncio
@respx.mock
async def test_citation_resolver_fabricated_doi_is_rejected() -> None:
    fake_doi = "10.9999/FAKE-fake-fake"
    respx.get(f"https://doi.org/{fake_doi}").mock(return_value=httpx.Response(404))
    resolver = RealCitationResolver(source_tiers=load_source_tiers())
    ref = Reference(
        title="Totally Made Up Paper",
        url=f"https://doi.org/{fake_doi}",
        doi=fake_doi,
        why_relevant="Should be rejected.",
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    )
    out = await resolver.resolve(ref)
    assert out.tier_0_drop is False
    assert out.reference is None


@pytest.mark.asyncio
@respx.mock
async def test_citation_resolver_tier_0_url_is_rejected_before_http() -> None:
    route = respx.get("https://www.facebook.com/share/abc").mock(return_value=httpx.Response(200))
    resolver = RealCitationResolver(source_tiers=load_source_tiers())
    ref = Reference(
        title="Facebook post",
        url="https://www.facebook.com/share/abc",
        why_relevant="Tier-0 reference; must be dropped.",
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    )
    out = await resolver.resolve(ref)
    assert out.tier_0_drop is True
    assert out.reference is None
    assert route.called is False


@pytest.mark.asyncio
@respx.mock
async def test_citation_resolver_url_only_reference_resolves_when_200() -> None:
    url = "https://www.nature.com/articles/abc"
    respx.get(url).mock(
        return_value=httpx.Response(
            200,
            html="<html><head><title>Some article</title></head></html>",
        )
    )
    resolver = RealCitationResolver(source_tiers=load_source_tiers())
    ref = Reference(
        title="Some article",
        url=url,
        why_relevant="Real article.",
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    )
    out = await resolver.resolve(ref)
    assert out.tier_0_drop is False
    assert out.reference is not None
    assert out.reference.verified is True


@pytest.mark.asyncio
async def test_fake_citation_resolver_returns_canned_results() -> None:
    ref = Reference(
        title="Canned",
        url="https://www.nature.com/articles/abc",
        why_relevant="Fake fixture.",
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    )
    resolver = FakeCitationResolver(
        outcomes={
            "https://www.nature.com/articles/abc": CitationOutcome(
                reference=ref.model_copy(update={"verified": True}),
                tier_0_drop=False,
            )
        }
    )
    out = await resolver.resolve(ref)
    assert out.reference is not None
    assert out.reference.verified is True
