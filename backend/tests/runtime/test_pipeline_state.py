"""Tests for the runtime pipeline-state container (Step 21)."""

from __future__ import annotations

import pytest
from pydantic import ValidationError

from app.runtime.pipeline_state import PipelineState
from app.schemas.literature_qc import LiteratureQCResult, NoveltyLabel


def test_pipeline_state_round_trips_through_pydantic() -> None:
    qc = LiteratureQCResult(novelty=NoveltyLabel.NOT_FOUND)
    state = PipelineState(
        request_id="abc-123",
        hypothesis="Trehalose preserves HeLa viability better than sucrose at -80C.",
        qc_result=qc,
    )
    dumped = state.model_dump()
    rebuilt = PipelineState.model_validate(dumped)
    assert rebuilt.request_id == "abc-123"
    assert rebuilt.qc_result is not None
    assert rebuilt.qc_result.novelty is NoveltyLabel.NOT_FOUND


def test_pipeline_state_request_id_is_required() -> None:
    with pytest.raises(ValidationError):
        PipelineState.model_validate({"hypothesis": "abc"})


def test_pipeline_state_few_shot_examples_default_to_empty_list() -> None:
    state = PipelineState(request_id="abc", hypothesis="x" * 10)
    assert state.few_shot_examples == []
    assert state.qc_result is None
    assert state.final_plan is None
