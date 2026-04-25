"""Step 52 — smoke tests over `backend/README.md`.

These are the contract for the documentation deliverable defined in
`.cursor/agents/implementation-agent.md`. The README is a first-class
artefact: a teammate cloning the repo should be able to follow it from
zero to a successful `POST /generate-plan` against one of the four
sample hypotheses with no extra Slack questions.
"""

from __future__ import annotations

from pathlib import Path

import pytest

README = Path(__file__).resolve().parents[1] / "README.md"

REQUIRED_HEADINGS = (
    "What this is",
    "Runtime architecture",
    "Prerequisites",
    "Install",
    "Configure",
    "Run the server",
    "API reference",
    "Sample data",
    "End-to-end walkthrough",
    "Project structure",
    "How it works",
    "Trust & anti-hallucination guarantees",
    "Observability & error contract",
    "Development",
    "Troubleshooting",
)


@pytest.fixture(scope="module")
def readme_text() -> str:
    if not README.exists():
        raise AssertionError(
            f"missing canonical backend README at {README}; Step 52 is incomplete."
        )
    return README.read_text(encoding="utf-8")


def test_readme_contains_all_required_section_headings(readme_text: str) -> None:
    """All 15 sections from the implementation-agent spec must be present."""

    missing = [h for h in REQUIRED_HEADINGS if h not in readme_text]
    assert not missing, f"backend/README.md is missing required section headings: {missing}"


def test_readme_contains_invoke_restmethod_and_curl_examples(
    readme_text: str,
) -> None:
    """Every endpoint-example must include both PowerShell *and* curl
    invocations (per `.cursor/agents/implementation-agent.md` §7)."""

    assert "Invoke-RestMethod" in readme_text, (
        "README must include at least one PowerShell `Invoke-RestMethod` example."
    )
    assert "curl.exe" in readme_text, (
        "README must include at least one `curl.exe` example for cross-shell users."
    )
    for endpoint in ("/generate-plan", "/feedback", "/health"):
        assert endpoint in readme_text, f"README must document the `{endpoint}` endpoint."


def test_readme_contains_powershell_install_block(readme_text: str) -> None:
    """The install section must show a copy-pasteable PowerShell venv block."""

    assert "python -m venv .venv" in readme_text, (
        "README install section must show `python -m venv .venv` "
        "(the canonical Windows/PowerShell setup)."
    )
    assert ".\\.venv\\Scripts\\Activate.ps1" in readme_text, (
        "README install section must show the PowerShell venv activation step."
    )
