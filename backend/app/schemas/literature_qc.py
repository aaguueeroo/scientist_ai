"""Schemas for the literature-QC runtime agent and the source-trust tier system."""

from __future__ import annotations

from enum import StrEnum
from typing import Literal

from pydantic import Field

from app.schemas.openai_structured_model import OpenAIStructuredModel


class SourceTier(StrEnum):
    """Trust tier assigned by the in-process classifier (never the LLM)."""

    TIER_1_PEER_REVIEWED = "tier_1_peer_reviewed"
    TIER_2_PREPRINT_OR_COMMUNITY = "tier_2_preprint_or_community"
    TIER_3_GENERAL_WEB = "tier_3_general_web"
    TIER_0_FORBIDDEN = "tier_0_forbidden"


class NoveltyLabel(StrEnum):
    """Novelty signal emitted by runtime Agent 1."""

    NOT_FOUND = "not_found"
    SIMILAR_WORK_EXISTS = "similar_work_exists"
    EXACT_MATCH = "exact_match"


class Reference(OpenAIStructuredModel):
    """A literature reference attached to a QC result or experiment plan.

    URL fields are plain ``str`` so OpenAI ``response_format`` JSON Schemas
    (Agent 1 / Agent 3) do not use ``format: "uri"``, which the API rejects.
    """

    title: str = Field(min_length=1, max_length=500)
    url: str = Field(
        min_length=1,
        max_length=2048,
        description="Candidate article URL; resolved when verified.",
    )
    doi: str | None = None
    why_relevant: str = Field(max_length=400)
    tier: SourceTier
    verified: bool = False
    verification_url: str | None = Field(default=None, max_length=2048)
    confidence: Literal["high", "medium", "low"] = "low"
    is_similarity_suggestion: bool = Field(
        default=False,
        description=(
            "True when this row is a best-effort similar link only (Tavily / model "
            "suggestion), not passed through the HTTP citation resolver as verified."
        ),
    )
    tavily_score: float | None = Field(
        default=None,
        ge=0.0,
        le=1.0,
        description=(
            "Tavily search relevance score for this work, when the URL was returned "
            "in a Tavily result (typically max score across queries for this URL/work)."
        ),
    )


class LiteratureQCResult(OpenAIStructuredModel):
    """Output of runtime Agent 1 (literature QC)."""

    novelty: NoveltyLabel
    references: list[Reference] = Field(
        default_factory=list,
        max_length=5,
        description="HTTP-verified references only (citation resolver), max 5.",
    )
    similarity_suggestion: Reference | None = Field(
        default=None,
        description=(
            "When ``references`` is empty, up to one unverified 'similar' link may "
            "be attached (domain-restricted Tavily, optional open-web Tavily fallback, "
            "or a non–tier-0 LLM claim). Omitted in JSON when null."
        ),
    )
    confidence: Literal["high", "medium", "low"] = "low"
    tier_0_drops: int = 0
