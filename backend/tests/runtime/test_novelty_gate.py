"""Tests for the pure novelty-gate decision function (Step 20)."""

from __future__ import annotations

from app.runtime.novelty_gate import Continue, StopWithQC, decide
from app.schemas.literature_qc import NoveltyLabel


def test_novelty_gate_exact_match_returns_stop_with_qc() -> None:
    out = decide(NoveltyLabel.EXACT_MATCH)
    assert isinstance(out, StopWithQC)
    assert out.kind == "stop_with_qc"


def test_novelty_gate_similar_work_exists_returns_continue() -> None:
    out = decide(NoveltyLabel.SIMILAR_WORK_EXISTS)
    assert isinstance(out, Continue)
    assert out.kind == "continue"


def test_novelty_gate_not_found_returns_continue() -> None:
    out = decide(NoveltyLabel.NOT_FOUND)
    assert isinstance(out, Continue)
    assert out.kind == "continue"
