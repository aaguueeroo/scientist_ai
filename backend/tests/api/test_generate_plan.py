"""Skeleton tests for the POST /generate-plan input contract.

Step 12 only pins `GeneratePlanRequest`. The full route + orchestrator
wiring is exercised in later steps (Step 25, Step 34).
"""

from __future__ import annotations

import pytest
from pydantic import ValidationError

from app.schemas.hypothesis import GeneratePlanRequest


def test_generate_plan_request_accepts_valid_hypothesis() -> None:
    body = GeneratePlanRequest(
        hypothesis="Trehalose preserves HeLa viability better than sucrose at -80C.",
    )
    assert body.hypothesis.startswith("Trehalose")


def test_generate_plan_request_rejects_too_short_hypothesis() -> None:
    with pytest.raises(ValidationError):
        GeneratePlanRequest(hypothesis="too short")


def test_generate_plan_request_rejects_too_long_hypothesis() -> None:
    with pytest.raises(ValidationError):
        GeneratePlanRequest(hypothesis="x" * 2001)
