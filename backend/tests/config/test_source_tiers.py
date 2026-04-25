"""Tests for the source-trust tier classifier (Step 14)."""

from __future__ import annotations

from app.config.source_tiers import load_source_tiers
from app.schemas.literature_qc import SourceTier


def test_classify_tier_1_hostname_returns_tier_1() -> None:
    cfg = load_source_tiers()
    assert (
        cfg.classify("https://www.nature.com/articles/s41586-020-2649-2")
        == SourceTier.TIER_1_PEER_REVIEWED
    )


def test_classify_tier_2_hostname_returns_tier_2() -> None:
    cfg = load_source_tiers()
    assert (
        cfg.classify("https://arxiv.org/abs/2401.00001") == SourceTier.TIER_2_PREPRINT_OR_COMMUNITY
    )


def test_classify_tier_3_hostname_returns_tier_3() -> None:
    cfg = load_source_tiers()
    assert cfg.classify("https://example.com/some/path") == SourceTier.TIER_3_GENERAL_WEB


def test_classify_tier_0_hostname_returns_tier_0() -> None:
    cfg = load_source_tiers()
    assert cfg.classify("https://www.facebook.com/share/abc") == SourceTier.TIER_0_FORBIDDEN


def test_classify_doi_prefix_for_known_publisher_returns_tier_1() -> None:
    cfg = load_source_tiers()
    assert (
        cfg.classify("https://doi.org/10.1038/s41586-020-2649-2") == SourceTier.TIER_1_PEER_REVIEWED
    )


def test_tavily_include_domains_is_union_of_t1_t2_and_supplier_hosts() -> None:
    cfg = load_source_tiers()
    domains = cfg.tavily_include_domains()
    assert "nature.com" in domains
    assert "arxiv.org" in domains
    assert "sigmaaldrich.com" in domains
    assert "facebook.com" not in domains
    assert len(domains) == len(set(domains))


def test_classify_subdomain_falls_through_to_parent_host() -> None:
    cfg = load_source_tiers()
    assert cfg.classify("https://pubmed.ncbi.nlm.nih.gov/12345") == SourceTier.TIER_1_PEER_REVIEWED


def test_classify_tier_0_takes_precedence_over_tier_1() -> None:
    cfg = load_source_tiers()
    assert cfg.classify("https://www.facebook.com/post/abc") == SourceTier.TIER_0_FORBIDDEN
