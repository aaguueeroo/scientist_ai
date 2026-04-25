"""Pinning tests for runtime-agent role files (Steps 9-11)."""

from __future__ import annotations

from pathlib import Path

import pytest

from app.prompts.loader import PROMPTS_DIR

REQUIRED_CLAUSES: tuple[str, ...] = (
    "do not invent",
    "cite",
    "tier",
    "ignore",
)
"""Substrings required (case-insensitive) in every role file. The role
must also contain `refuse` OR `unverified`."""


def _role_path(name: str) -> Path:
    return PROMPTS_DIR / name


def _read(name: str) -> str:
    return _role_path(name).read_text(encoding="utf-8")


@pytest.mark.parametrize(
    "role_file",
    ["literature_qc.md", "feedback_relevance.md", "experiment_planner.md"],
)
def test_role_file_exists_and_nonempty(role_file: str) -> None:
    path = _role_path(role_file)
    assert path.exists(), f"role file missing: {path}"
    raw = _read(role_file).encode("utf-8")
    assert len(raw) >= 200, f"role file {role_file} too short ({len(raw)} bytes)"


@pytest.mark.parametrize(
    "role_file",
    ["literature_qc.md", "feedback_relevance.md", "experiment_planner.md"],
)
def test_role_file_pins_required_clauses(role_file: str) -> None:
    text = _read(role_file).lower()
    for clause in REQUIRED_CLAUSES:
        assert clause in text, f"missing required clause {clause!r} in {role_file}"
    assert ("refuse" in text) or ("unverified" in text), (
        f"role file {role_file} must mention refusal/unverified policy"
    )


def test_literature_qc_role_pins_required_clauses() -> None:
    text = _read("literature_qc.md").lower()
    for clause in REQUIRED_CLAUSES:
        assert clause in text


def test_feedback_relevance_role_pins_required_clauses() -> None:
    text = _read("feedback_relevance.md").lower()
    for clause in REQUIRED_CLAUSES:
        assert clause in text


def test_experiment_planner_role_pins_required_clauses() -> None:
    text = _read("experiment_planner.md").lower()
    for clause in REQUIRED_CLAUSES:
        assert clause in text
    assert "unverified" in text, "experiment_planner role must use unverified flag"
