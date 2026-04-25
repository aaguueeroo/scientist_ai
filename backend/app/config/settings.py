"""Pydantic-settings backed application configuration.

Per `docs/research.md` §12, every runtime agent gets a pinned model, seed,
temperature, and max_tokens. The values default here are the canonical ones;
they may be overridden via environment variables for cassette regeneration.
"""

from __future__ import annotations

from functools import lru_cache

from pydantic import Field, SecretStr
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
        ...,
        description="API key for OpenAI (required).",
    )
    TAVILY_API_KEY: SecretStr = Field(
        ...,
        description="API key for Tavily web search (required).",
    )

    MAX_REQUEST_USD: float = Field(
        default=0.60,
        ge=0.0,
        description="Hard per-request OpenAI cost ceiling (USD).",
    )
    RATE_LIMIT_PER_MIN: int = Field(
        default=30,
        ge=1,
        description="Per-IP rate limit applied to /generate-plan and /feedback.",
    )

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
