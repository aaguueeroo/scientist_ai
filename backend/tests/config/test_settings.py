from __future__ import annotations

import pytest
from pydantic import ValidationError

from app.config.settings import Settings, get_settings


def _clear_env_keys(monkeypatch: pytest.MonkeyPatch) -> None:
    for key in (
        "OPENAI_API_KEY",
        "TAVILY_API_KEY",
        "MAX_REQUEST_USD",
        "RATE_LIMIT_PER_MIN",
        "OPENAI_MODEL_LITERATURE_QC",
        "OPENAI_MODEL_FEEDBACK_RELEVANCE",
        "OPENAI_MODEL_EXPERIMENT_PLANNER",
    ):
        monkeypatch.delenv(key, raising=False)


def test_settings_loads_from_env_returns_expected_keys(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _clear_env_keys(monkeypatch)
    monkeypatch.setenv("OPENAI_API_KEY", "sk-test")
    monkeypatch.setenv("TAVILY_API_KEY", "tvly-test")
    get_settings.cache_clear()
    settings = get_settings()
    assert settings.OPENAI_API_KEY.get_secret_value() == "sk-test"
    assert settings.TAVILY_API_KEY.get_secret_value() == "tvly-test"


def test_settings_missing_openai_key_raises_clear_error(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _clear_env_keys(monkeypatch)
    monkeypatch.setenv("TAVILY_API_KEY", "tvly-test")
    get_settings.cache_clear()
    with pytest.raises(ValidationError) as exc_info:
        Settings(_env_file=None)
    assert "OPENAI_API_KEY" in str(exc_info.value)


def test_settings_default_max_request_usd_is_zero_point_six(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _clear_env_keys(monkeypatch)
    monkeypatch.setenv("OPENAI_API_KEY", "sk-test")
    monkeypatch.setenv("TAVILY_API_KEY", "tvly-test")
    get_settings.cache_clear()
    settings = get_settings()
    assert settings.MAX_REQUEST_USD == pytest.approx(0.60)
    assert settings.RATE_LIMIT_PER_MIN == 30


def test_settings_pinned_model_strings_match_research(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _clear_env_keys(monkeypatch)
    monkeypatch.setenv("OPENAI_API_KEY", "sk-test")
    monkeypatch.setenv("TAVILY_API_KEY", "tvly-test")
    get_settings.cache_clear()
    settings = get_settings()
    assert settings.OPENAI_MODEL_LITERATURE_QC == "gpt-4.1-mini"
    assert settings.OPENAI_MODEL_FEEDBACK_RELEVANCE == "gpt-4.1-mini"
    assert settings.OPENAI_MODEL_EXPERIMENT_PLANNER == "gpt-4.1"
    assert settings.OPENAI_SEED_LITERATURE_QC == 7
    assert settings.OPENAI_SEED_FEEDBACK_DOMAIN == 11
    assert settings.OPENAI_SEED_FEEDBACK_RERANK == 13
    assert settings.OPENAI_SEED_EXPERIMENT_PLANNER == 23
