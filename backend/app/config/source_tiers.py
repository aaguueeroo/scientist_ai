"""Source-trust tier classifier.

The LLM is never asked to classify trust tier. Tier comes from
`source_tiers.yaml` via this module: code, not the model, decides the
tier. Tier-0 takes precedence over every other rule, so a malicious URL
on a forbidden host can never be promoted by a DOI prefix or other
rule.
"""

from __future__ import annotations

from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from urllib.parse import urlparse

import yaml

from app.schemas.literature_qc import SourceTier

DEFAULT_PATH = Path(__file__).parent / "source_tiers.yaml"


@dataclass(frozen=True)
class SourceTiersConfig:
    """In-memory representation of `source_tiers.yaml`."""

    tier_1_hostnames: frozenset[str]
    tier_1_doi_prefixes: tuple[str, ...]
    tier_1_supplier_hostnames: frozenset[str]
    tier_2_hostnames: frozenset[str]
    tier_0_hostnames: frozenset[str]

    def classify(self, url: str) -> SourceTier:
        """Return the trust tier for a URL.

        Tier-0 first; then DOI prefix (when on `doi.org`); then exact
        host or registrable-domain match in T1, T2; else T3.
        """

        host = (urlparse(url).hostname or "").lower()
        if host == "":
            return SourceTier.TIER_3_GENERAL_WEB

        if _host_matches(host, self.tier_0_hostnames):
            return SourceTier.TIER_0_FORBIDDEN

        if host in {"doi.org", "dx.doi.org"}:
            path = urlparse(url).path.lstrip("/")
            for prefix in self.tier_1_doi_prefixes:
                if path.startswith(f"{prefix}/"):
                    return SourceTier.TIER_1_PEER_REVIEWED

        if _host_matches(host, self.tier_1_hostnames):
            return SourceTier.TIER_1_PEER_REVIEWED

        if _host_matches(host, self.tier_1_supplier_hostnames):
            return SourceTier.TIER_1_PEER_REVIEWED

        if _host_matches(host, self.tier_2_hostnames):
            return SourceTier.TIER_2_PREPRINT_OR_COMMUNITY

        return SourceTier.TIER_3_GENERAL_WEB

    def tavily_include_domains(self) -> list[str]:
        """Hostname allowlist for Tavily.

        Union of Tier 1 hostnames + Tier 2 hostnames +
        Tier-1 supplier hostnames. We **drop** a hostname if it is a **proper
        subdomain of** another host in the set (e.g. keep ``nlm.nih.gov`` and
        drop ``pmc.ncbi.lnm.nih.gov``) so the API sees a **shorter** list. Tavily
        documents "keep domain lists short" for best results; an overly long
        ``include_domains`` list often returns **no** results for difficult
        queries even when unrestricted search finds good pages on those hosts.
        Classifier :meth:`classify` still uses the full YAML sets (subdomain
        matching via :func:`_host_matches`), so behaviour for URLs is unchanged.
        """
        union = self.tier_1_hostnames | self.tier_2_hostnames | self.tier_1_supplier_hostnames
        return _minimize_domains_for_tavily(union)


def _host_matches(host: str, allowlist: frozenset[str]) -> bool:
    """True iff `host` equals or is a subdomain of any allowlisted host."""

    if host in allowlist:
        return True
    for allowed in allowlist:
        if host.endswith(f".{allowed}"):
            return True
    return False


def _minimize_domains_for_tavily(hosts: frozenset[str] | set[str]) -> list[str]:
    """Omit a host if it is a strict subdomain of another host in the set."""

    hset: set[str] = set(hosts)
    remove: set[str] = set()
    for h in hset:
        for parent in hset:
            if h != parent and h.endswith(f".{parent}"):
                remove.add(h)
    kept = hset - remove
    return sorted(kept)


@lru_cache(maxsize=4)
def load_source_tiers(path: str | None = None) -> SourceTiersConfig:
    """Read `source_tiers.yaml` once and return a cached classifier."""

    yaml_path = Path(path) if path is not None else DEFAULT_PATH
    raw = yaml.safe_load(yaml_path.read_text(encoding="utf-8"))

    t1 = raw.get("tier_1_peer_reviewed", {})
    t2 = raw.get("tier_2_preprint_or_community", {})
    t0 = raw.get("tier_0_forbidden", {})

    return SourceTiersConfig(
        tier_1_hostnames=frozenset(t1.get("hostnames", [])),
        tier_1_doi_prefixes=tuple(t1.get("doi_prefixes", [])),
        tier_1_supplier_hostnames=frozenset(t1.get("supplier_hostnames_for_catalog", [])),
        tier_2_hostnames=frozenset(t2.get("hostnames", [])),
        tier_0_hostnames=frozenset(t0.get("hostnames", [])),
    )
