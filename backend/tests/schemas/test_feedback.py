"""Tests for `app/schemas/feedback.py` (Step 39)."""

from __future__ import annotations

import pytest
from pydantic import ValidationError

from app.schemas.feedback import (
    DomainTag,
    FeedbackRequest,
    FewShotExample,
)


def test_domain_tag_enum_includes_other_bucket() -> None:
    assert DomainTag.OTHER.value == "other"
    assert DomainTag.DIAGNOSTICS_BIOSENSOR.value == "diagnostics-biosensor"
    assert DomainTag.MICROBIOME_MOUSE_MODEL.value == "microbiome-mouse-model"
    assert DomainTag.CELL_BIOLOGY_CRYOPRESERVATION.value == "cell-biology-cryopreservation"
    assert DomainTag.SYNTHETIC_BIOLOGY_BIOELECTRO.value == "synthetic-biology-bioelectro"


def test_feedback_request_rejects_empty_corrected_field() -> None:
    with pytest.raises(ValidationError):
        FeedbackRequest(
            plan_id="plan-001",
            domain_tag=DomainTag.OTHER,
            corrected_field="",
            before="old",
            after="new",
            reason="more accurate",
        )


def test_few_shot_example_relevance_score_clamped_zero_to_one() -> None:
    valid = FewShotExample(
        corrected_field="materials[0].vendor",
        before="acme",
        after="Sigma-Aldrich",
        reason="standard supplier",
        domain_tag=DomainTag.CELL_BIOLOGY_CRYOPRESERVATION,
        relevance_score=0.5,
    )
    assert valid.relevance_score == 0.5

    with pytest.raises(ValidationError):
        FewShotExample(
            corrected_field="materials[0].vendor",
            before="acme",
            after="Sigma-Aldrich",
            reason="standard supplier",
            domain_tag=DomainTag.CELL_BIOLOGY_CRYOPRESERVATION,
            relevance_score=1.5,
        )

    with pytest.raises(ValidationError):
        FewShotExample(
            corrected_field="materials[0].vendor",
            before="acme",
            after="Sigma-Aldrich",
            reason="standard supplier",
            domain_tag=DomainTag.CELL_BIOLOGY_CRYOPRESERVATION,
            relevance_score=-0.1,
        )
