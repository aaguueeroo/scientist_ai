"""Schemas for the literature-QC runtime agent and the source-trust tier system."""

from __future__ import annotations

from enum import StrEnum
from typing import Literal

from pydantic import BaseModel, Field, HttpUrl


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


class Reference(BaseModel):
    """A literature reference attached to a QC result or experiment plan."""

    title: str = Field(min_length=1, max_length=500)
    url: HttpUrl
    doi: str | None = None
    why_relevant: str = Field(max_length=400)
    tier: SourceTier
    verified: bool = False
    verification_url: HttpUrl | None = None
    confidence: Literal["high", "medium", "low"] = "low"


class LiteratureQCResult(BaseModel):
    """Output of runtime Agent 1 (literature QC)."""

    novelty: NoveltyLabel
    references: list[Reference] = Field(default_factory=list, max_length=3)
    confidence: Literal["high", "medium", "low"] = "low"
    tier_0_drops: int = 0
