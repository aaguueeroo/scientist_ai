"""Role-file loader and prompt version hashing.

Three role files live in this directory and are loaded at runtime by a
single function. Their sha256 fingerprints are exposed via
`prompt_versions()` and stamped onto every persisted row and per-request
log line — the LLM never touches `prompt_versions`.
"""

from __future__ import annotations

import hashlib
from functools import lru_cache
from pathlib import Path
from typing import Final

ROLE_FILE_NAMES: Final[tuple[str, ...]] = (
    "literature_qc.md",
    "feedback_relevance.md",
    "experiment_planner.md",
)

PROMPTS_DIR: Path = Path(__file__).resolve().parent


@lru_cache(maxsize=8)
def load_role(name: str) -> str:
    """Return the UTF-8 text of role file `name` (e.g. `literature_qc.md`)."""

    if name not in ROLE_FILE_NAMES:
        raise KeyError(f"unknown role file: {name!r}")
    path = PROMPTS_DIR / name
    return path.read_text(encoding="utf-8")


def prompt_versions() -> dict[str, str]:
    """Return `{role_file_name: sha256_hex}` for every role file."""

    versions: dict[str, str] = {}
    for name in ROLE_FILE_NAMES:
        text = load_role(name)
        versions[name] = hashlib.sha256(text.encode("utf-8")).hexdigest()
    return versions
