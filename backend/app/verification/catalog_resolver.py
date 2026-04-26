"""Catalog resolver: turns LLM-claimed SKUs into verified `Material` rows.

The LLM is never trusted to mark a `Material` verified. The runtime
pipeline takes each candidate `Material` from Agent 3 and runs it
through this resolver. The resolver knows a small table of
supplier-pattern URLs (Sigma-Aldrich, Thermo Fisher) and will fetch the
URL with `httpx`, asserting the SKU appears verbatim in the response
body before flipping `verified=True`. Suppliers are filtered through
the same source-tier classifier so a Tier-0 host can never reach the
outbound HTTP layer.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass

import httpx

from app.config.source_tiers import SourceTiersConfig
from app.schemas.experiment_plan import Material
from app.schemas.literature_qc import SourceTier

_SUPPLIER_PATTERNS: dict[str, str] = {
    "sigma-aldrich": "https://www.sigmaaldrich.com/US/en/product/sigma/{sku}",
    "sigmaaldrich": "https://www.sigmaaldrich.com/US/en/product/sigma/{sku}",
    "sigma": "https://www.sigmaaldrich.com/US/en/product/sigma/{sku}",
    "thermofisher": "https://www.thermofisher.com/order/catalog/product/{sku}",
    "thermo fisher": "https://www.thermofisher.com/order/catalog/product/{sku}",
    "thermo": "https://www.thermofisher.com/order/catalog/product/{sku}",
}


class AbstractCatalogResolver(ABC):
    """Resolver interface used by runtime agents and the orchestrator."""

    @abstractmethod
    async def resolve(self, material: Material) -> Material:
        """Resolve `material` and return a (verified or unverified) copy."""


@dataclass
class RealCatalogResolver(AbstractCatalogResolver):
    """`httpx`-backed resolver that checks the supplier page for the SKU."""

    source_tiers: SourceTiersConfig
    timeout_s: float = 5.0

    async def resolve(self, material: Material) -> Material:
        if not material.vendor.strip() or not material.sku.strip():
            return _mark_unverified(material, "missing vendor or sku")

        vendor_key = material.vendor.strip().lower()
        pattern = _SUPPLIER_PATTERNS.get(vendor_key)
        if pattern is None:
            return _mark_unverified(material, f"unknown supplier {material.vendor!r}")

        url = pattern.format(sku=material.sku)
        tier = self.source_tiers.classify(url)
        if tier is SourceTier.TIER_0_FORBIDDEN:
            return _mark_unverified(material, "supplier host is Tier-0 forbidden")

        async with httpx.AsyncClient(timeout=self.timeout_s, follow_redirects=True) as client:
            try:
                response = await client.get(url)
            except httpx.HTTPError as exc:
                return _mark_unverified(material, f"http error: {exc.__class__.__name__}")

        if response.status_code != 200:
            return _mark_unverified(
                material, f"supplier 404/{response.status_code} for {material.sku}"
            )

        body = response.text or ""
        if material.sku not in body:
            return _mark_unverified(material, f"sku {material.sku!r} not found in supplier page")

        return material.model_copy(
            update={
                "verified": True,
                "verification_url": url,
                "confidence": "high",
                "tier": tier,
            }
        )


def _mark_unverified(material: Material, reason: str) -> Material:
    return material.model_copy(
        update={
            "verified": False,
            "confidence": "low",
            "notes": reason,
        }
    )


@dataclass
class FakeCatalogResolver(AbstractCatalogResolver):
    """Table-driven resolver used in unit tests."""

    outcomes: dict[str, Material]

    async def resolve(self, material: Material) -> Material:
        if material.sku is not None and material.sku in self.outcomes:
            return self.outcomes[material.sku]
        return _mark_unverified(material, "no canned outcome")
