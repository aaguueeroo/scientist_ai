"""Tests for `app/prompts/loader.py`."""

from __future__ import annotations

import hashlib
import pathlib

import pytest

from app.prompts.loader import (
    ROLE_FILE_NAMES,
    load_role,
    prompt_versions,
)


def test_loader_load_role_returns_file_bytes_decoded() -> None:
    text = load_role("literature_qc.md")
    assert isinstance(text, str)
    assert len(text) >= 1


def test_loader_load_role_unknown_name_raises_keyerror() -> None:
    with pytest.raises(KeyError):
        load_role("not_a_real_role.md")


def test_loader_prompt_versions_returns_one_entry_per_role_file() -> None:
    versions = prompt_versions()
    assert set(versions.keys()) == set(ROLE_FILE_NAMES)
    for value in versions.values():
        assert isinstance(value, str)
        assert len(value) == 64  # sha256 hex length


def test_loader_prompt_versions_hash_changes_when_file_changes(
    tmp_path: pathlib.Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from app.prompts import loader

    work_dir = tmp_path / "prompts"
    work_dir.mkdir(parents=True)
    for name in ROLE_FILE_NAMES:
        (work_dir / name).write_text("initial-content", encoding="utf-8")

    monkeypatch.setattr(loader, "PROMPTS_DIR", work_dir)
    loader.load_role.cache_clear()

    before = prompt_versions()
    expected_initial = hashlib.sha256(b"initial-content").hexdigest()
    assert before["literature_qc.md"] == expected_initial

    (work_dir / "literature_qc.md").write_text("changed-content", encoding="utf-8")
    loader.load_role.cache_clear()

    after = prompt_versions()
    assert after["literature_qc.md"] != before["literature_qc.md"]
    assert after["feedback_relevance.md"] == before["feedback_relevance.md"]
