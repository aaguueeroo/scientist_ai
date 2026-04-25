"""Step 51 — assertions over `backend/scripts/check.ps1`.

The script is the canonical "all checks" command for the backend. It
must run the four documented commands in order and stop on the first
failure (PowerShell `$ErrorActionPreference = "Stop"`).
"""

from __future__ import annotations

from pathlib import Path

import pytest

CHECK_SCRIPT = Path(__file__).resolve().parents[2] / "scripts" / "check.ps1"


@pytest.fixture(scope="module")
def script_text() -> str:
    if not CHECK_SCRIPT.exists():
        raise AssertionError(f"missing canonical check script at {CHECK_SCRIPT}")
    return CHECK_SCRIPT.read_text(encoding="utf-8")


def test_check_script_runs_four_commands_in_documented_order(
    script_text: str,
) -> None:
    """The script must invoke pytest, ruff format, ruff check, mypy in order."""

    expected = [
        "pytest -q",
        "ruff format backend",
        "ruff check backend",
        "mypy --strict backend",
    ]
    indices = []
    for needle in expected:
        idx = script_text.find(needle)
        assert idx != -1, (
            f"check.ps1 must contain '{needle}'; this is the canonical 'all checks' command set."
        )
        indices.append(idx)
    assert indices == sorted(indices), (
        f"commands appear out of order: {expected} -> indices {indices}"
    )


def test_check_script_uses_powershell_stop_on_first_failure(
    script_text: str,
) -> None:
    """`$ErrorActionPreference = "Stop"` makes PowerShell abort on the first
    non-zero exit, ensuring we don't mask a failing pytest with a passing
    ruff."""

    assert '$ErrorActionPreference = "Stop"' in script_text, (
        'check.ps1 must set $ErrorActionPreference = "Stop" so the '
        "first non-zero exit aborts the run."
    )
