"""Test fixtures shared across the backend test suite."""

from __future__ import annotations

import pytest


@pytest.fixture(autouse=True)
def _patch_required_env(monkeypatch: pytest.MonkeyPatch) -> None:
    """Default test env: provide dummy keys so `Settings()` succeeds."""

    monkeypatch.setenv("OPENAI_API_KEY", "sk-test")
    monkeypatch.setenv("TAVILY_API_KEY", "tvly-test")

    from app.config.settings import get_settings

    get_settings.cache_clear()
