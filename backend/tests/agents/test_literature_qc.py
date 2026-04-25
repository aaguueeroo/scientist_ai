"""Tests for the literature-QC schema (Step 13)."""

from __future__ import annotations

import pytest
from pydantic import ValidationError

from app.schemas.literature_qc import (
    LiteratureQCResult,
    NoveltyLabel,
    Reference,
    SourceTier,
)


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
