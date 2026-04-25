"""Tests for the catalog resolver (Step 27)."""

# Pydantic v2 coerces plain string URLs into `HttpUrl` at validation time,
# but the pydantic mypy plugin rejects `str` arguments to `HttpUrl` fields.
# Fixtures here use literal URLs as `str`; silence the arg-type noise.
# mypy: disable-error-code="arg-type"

from __future__ import annotations

import httpx
import pytest
import respx

from app.config.source_tiers import load_source_tiers
from app.schemas.experiment_plan import Material
from app.schemas.literature_qc import SourceTier
from app.verification.catalog_resolver import (
    FakeCatalogResolver,
    RealCatalogResolver,
)


@pytest.mark.asyncio
@respx.mock
async def test_catalog_resolver_known_sigma_sku_resolves_and_sets_verified_true() -> None:
    sku = "T9531"
    url = f"https://www.sigmaaldrich.com/US/en/product/sigma/{sku}"
    respx.get(url).mock(
        return_value=httpx.Response(
            200,
            html=f"<html><body>Trehalose dihydrate, Catalog #{sku}, BioReagent</body></html>",
        )
    )
    resolver = RealCatalogResolver(source_tiers=load_source_tiers())
    material = Material(
        reagent="Trehalose dihydrate",
        vendor="Sigma-Aldrich",
        sku=sku,
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    )
    out = await resolver.resolve(material)
    assert out.verified is True
    assert out.verification_url is not None
    assert sku in str(out.verification_url)
    assert out.confidence == "high"


@pytest.mark.asyncio
@respx.mock
async def test_catalog_resolver_fabricated_sku_is_rejected_with_verified_false() -> None:
    sku = "SKU-FAKE-DOES-NOT-EXIST"
    url = f"https://www.sigmaaldrich.com/US/en/product/sigma/{sku}"
    respx.get(url).mock(return_value=httpx.Response(404))
    resolver = RealCatalogResolver(source_tiers=load_source_tiers())
    material = Material(
        reagent="Made-up reagent",
        vendor="Sigma-Aldrich",
        sku=sku,
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    )
    out = await resolver.resolve(material)
    assert out.verified is False
    assert out.confidence == "low"
    assert out.notes is not None
    assert sku in (out.notes or "") or "404" in (out.notes or "")


@pytest.mark.asyncio
async def test_catalog_resolver_unknown_supplier_returns_unverified_low_confidence() -> None:
    resolver = RealCatalogResolver(source_tiers=load_source_tiers())
    material = Material(
        reagent="Some reagent",
        vendor="Unknown Vendor Ltd.",
        sku="X-1234",
        tier=SourceTier.TIER_3_GENERAL_WEB,
    )
    out = await resolver.resolve(material)
    assert out.verified is False
    assert out.confidence == "low"


@pytest.mark.asyncio
async def test_fake_catalog_resolver_returns_canned_results() -> None:
    in_material = Material(
        reagent="Trehalose dihydrate",
        vendor="Sigma-Aldrich",
        sku="T9531",
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    )
    canned = in_material.model_copy(
        update={
            "verified": True,
            "verification_url": "https://www.sigmaaldrich.com/US/en/product/sigma/T9531",
            "confidence": "high",
        }
    )
    resolver = FakeCatalogResolver(outcomes={"T9531": canned})
    out = await resolver.resolve(in_material)
    assert out.verified is True
    assert out.confidence == "high"
