"""Citation resolver: turns LLM-claimed references into verified ones.

The LLM cannot mark a reference verified. The runtime pipeline takes
each candidate `Reference` from Agent 1 / Agent 3 and runs it through
this resolver. Tier-0 hosts are rejected before the network call so a
malicious URL never reaches the outbound HTTP layer.
"""

from __future__ import annotations

import re
from abc import ABC, abstractmethod
from dataclasses import dataclass

import httpx
from pydantic import BaseModel

from app.config.source_tiers import SourceTiersConfig
from app.schemas.literature_qc import Reference, SourceTier

_TITLE_RE = re.compile(r"<title[^>]*>(.*?)</title>", re.IGNORECASE | re.DOTALL)
_TOKEN_RE = re.compile(r"[a-z0-9]{3,}", re.IGNORECASE)
_MIN_TITLE_TOKEN_OVERLAP = 3


class CitationOutcome(BaseModel):
    """Result of attempting to verify a reference."""

    reference: Reference | None
    tier_0_drop: bool


class AbstractCitationResolver(ABC):
    """Resolver interface used by runtime agents and the orchestrator."""

    @abstractmethod
    async def resolve(self, reference: Reference) -> CitationOutcome:
        """Resolve `reference` and return either a verified copy or `None`."""


@dataclass
class RealCitationResolver(AbstractCitationResolver):
    """`httpx`-backed resolver: HEAD/GET the DOI or URL and check the title."""

    source_tiers: SourceTiersConfig
    timeout_s: float = 5.0

    async def resolve(self, reference: Reference) -> CitationOutcome:
        url = str(reference.url)
        tier = self.source_tiers.classify(url)
        if tier is SourceTier.TIER_0_FORBIDDEN:
            return CitationOutcome(reference=None, tier_0_drop=True)

        async with httpx.AsyncClient(timeout=self.timeout_s, follow_redirects=True) as client:
            try:
                response = await client.get(url)
            except httpx.HTTPError:
                return CitationOutcome(reference=None, tier_0_drop=False)

        if response.status_code != 200:
            return CitationOutcome(reference=None, tier_0_drop=False)

        body = response.text or ""
        match = _TITLE_RE.search(body)
        page_title = match.group(1).strip() if match else ""

        if reference.doi is not None:
            if not _titles_overlap(reference.title, page_title):
                return CitationOutcome(reference=None, tier_0_drop=False)
        else:
            if page_title == "":
                return CitationOutcome(reference=None, tier_0_drop=False)

        verified = reference.model_copy(
            update={
                "verified": True,
                "verification_url": url,
                "confidence": "high",
                "tier": tier,
            }
        )
        return CitationOutcome(reference=verified, tier_0_drop=False)


def _titles_overlap(claimed: str, observed: str) -> bool:
    claimed_tokens = {tok.lower() for tok in _TOKEN_RE.findall(claimed)}
    observed_tokens = {tok.lower() for tok in _TOKEN_RE.findall(observed)}
    return len(claimed_tokens & observed_tokens) >= _MIN_TITLE_TOKEN_OVERLAP


@dataclass
class FakeCitationResolver(AbstractCitationResolver):
    """Table-driven resolver used in unit tests."""

    outcomes: dict[str, CitationOutcome]
    default: CitationOutcome | None = None

    async def resolve(self, reference: Reference) -> CitationOutcome:
        url = str(reference.url)
        if url in self.outcomes:
            return self.outcomes[url]
        if self.default is not None:
            return self.default
        return CitationOutcome(reference=None, tier_0_drop=False)
