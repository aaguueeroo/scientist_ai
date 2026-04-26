"""Pydantic-settings backed application configuration.

Per `docs/research.md` §12, every runtime agent gets a pinned model, seed,
temperature, and max_tokens. The values default here are the canonical ones;
they may be overridden via environment variables for cassette regeneration.
"""

from __future__ import annotations

import logging
from functools import lru_cache
from typing import Literal

from pydantic import Field, SecretStr, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Runtime configuration loaded from env vars (and optional `.env` file)."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore",
    )

    OPENAI_API_KEY: SecretStr = Field(
        default=SecretStr(""),
        description=(
            "Default API key for OpenAI when no per-request header and no DB row. "
            "May be empty if keys are supplied via `X-OpenAI-API-Key` or "
            "`PUT /settings/provider-api-keys`."
        ),
    )
    TAVILY_API_KEY: SecretStr = Field(
        default=SecretStr(""),
        description=(
            "Default API key for Tavily when no per-request header and no DB row. "
            "May be empty if keys are supplied via `X-Tavily-API-Key` or "
            "`PUT /settings/provider-api-keys`."
        ),
    )
    TAVILY_RETRIEVAL_MODE: Literal["search", "research"] = Field(
        default="search",
        description=(
            "Tavily Search API (`/search`, fast results) vs Research API "
            "(`/research`, multi-step report + sources; slower, higher cost)."
        ),
    )
    TAVILY_RESEARCH_MODEL: Literal["mini", "pro", "auto"] = Field(
        default="mini",
        description="Tavily Research agent model (only used when TAVILY_RETRIEVAL_MODE=research).",
    )

    MAX_REQUEST_USD: float = Field(
        default=0.60,
        ge=0.0,
        description="Hard per-request OpenAI cost ceiling (USD).",
    )
    RATE_LIMIT_PER_MIN: int = Field(
        default=30,
        ge=1,
        description=(
            "Per-IP rate limit applied to /literature-review, /experiment-plan, and /feedback."
        ),
    )

    LOG_LEVEL: str = Field(
        default="INFO",
        description="Stdlib/structlog level: DEBUG, INFO, WARNING, ERROR, or CRITICAL.",
    )
    LOG_DEBUG_PREVIEW_CHARS: int = Field(
        default=400,
        ge=0,
        le=10_000,
        description="Max characters for `query_preview` / body previews in DEBUG logs (0 = omit previews).",
    )

    @field_validator("LOG_LEVEL", mode="before")
    @classmethod
    def _normalize_log_level(cls, v: object) -> str:
        s = (str(v) if v is not None else "INFO").strip().upper() or "INFO"
        if s in ("DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"):
            return s
        return "INFO"

    def logging_level(self) -> int:
        """Return a `logging` module level constant (defaults to INFO if unknown)."""

        return getattr(logging, self.LOG_LEVEL, logging.INFO)

    DATABASE_URL: str = Field(
        default="sqlite+aiosqlite:///./ai_scientist.db",
        description="SQLAlchemy async URL for the plan/feedback store.",
    )

    OPENAI_MODEL_LITERATURE_QC: str = Field(default="gpt-4.1-mini")
    OPENAI_MODEL_FEEDBACK_RELEVANCE: str = Field(default="gpt-4.1-mini")
    OPENAI_MODEL_EXPERIMENT_PLANNER: str = Field(default="gpt-4.1")

    OPENAI_TEMP_LITERATURE_QC: float = Field(default=0.0, ge=0.0, le=2.0)
    OPENAI_TEMP_FEEDBACK_RELEVANCE: float = Field(default=0.0, ge=0.0, le=2.0)
    OPENAI_TEMP_EXPERIMENT_PLANNER: float = Field(default=0.0, ge=0.0, le=2.0)

    OPENAI_SEED_LITERATURE_QC: int = Field(default=7)
    OPENAI_SEED_FEEDBACK_DOMAIN: int = Field(default=11)
    OPENAI_SEED_FEEDBACK_RERANK: int = Field(default=13)
    OPENAI_SEED_EXPERIMENT_PLANNER: int = Field(default=23)

    OPENAI_MAX_TOKENS_LITERATURE_QC: int = Field(default=600, ge=1)
    OPENAI_MAX_TOKENS_FEEDBACK_DOMAIN: int = Field(default=80, ge=1)
    OPENAI_MAX_TOKENS_FEEDBACK_RERANK: int = Field(default=300, ge=1)
    OPENAI_MAX_TOKENS_EXPERIMENT_PLANNER: int = Field(default=4000, ge=1)

    # OpenAI 2026-04 published pricing (USD per token).
    OPENAI_PRICE_INPUT_PER_TOKEN_GPT_4_1: float = Field(default=2.0e-6)
    OPENAI_PRICE_OUTPUT_PER_TOKEN_GPT_4_1: float = Field(default=8.0e-6)
    OPENAI_PRICE_INPUT_PER_TOKEN_GPT_4_1_MINI: float = Field(default=0.4e-6)
    OPENAI_PRICE_OUTPUT_PER_TOKEN_GPT_4_1_MINI: float = Field(default=1.6e-6)


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """Cached settings factory; tests can `get_settings.cache_clear()`."""

    return Settings()
