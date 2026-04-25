"""Runtime Agent 1 — Literature QC.

Pipeline:
1. Build Q1 (verbatim hypothesis) and Q2 (LLM-extracted keywords).
2. Run two Tavily searches (the Tavily layer enforces include_domains).
3. Merge + deduplicate results; drop Tier-0 hits before any LLM call.
4. Ask gpt-4.1-mini (role: literature_qc.md, structured output) for the
   novelty label + candidate references + numeric confidence.
5. Apply the confidence floor (research §6.5).
6. Run each candidate reference through the citation resolver. The
   LLM never marks a reference verified.
7. Emit one structured log line with the per-request contract keys.
"""

from __future__ import annotations

import time
from dataclasses import dataclass

from pydantic import BaseModel, Field, HttpUrl

from app.clients.openai_client import (
    AbstractOpenAIClient,
    ChatMessage,
    ChatResult,
    ParsedResult,
)
from app.clients.tavily_client import AbstractTavilyClient, TavilyHit, TavilySearchResult
from app.config.settings import Settings, get_settings
from app.config.source_tiers import SourceTiersConfig
from app.observability.logging import emit_agent_call_complete
from app.prompts.loader import load_role, prompt_versions
from app.schemas.literature_qc import (
    LiteratureQCResult,
    NoveltyLabel,
    Reference,
    SourceTier,
)
from app.verification.citation_resolver import AbstractCitationResolver

_AGENT_NAME = "literature_qc"
_ROLE_FILE = "literature_qc.md"
_MAX_REFERENCES = 3
_MAX_HITS = 12


class ReferenceClaim(BaseModel):
    """A reference proposed by the LLM (unverified, untiered)."""

    title: str = Field(min_length=1, max_length=500)
    url: HttpUrl
    doi: str | None = None
    why_relevant: str = Field(min_length=1, max_length=400)


class NoveltyClaim(BaseModel):
    """The structured response Agent 1 asks the LLM to produce."""

    novelty: NoveltyLabel
    references: list[ReferenceClaim] = Field(default_factory=list, max_length=8)
    confidence: float = Field(ge=0.0, le=1.0)


@dataclass
class LiteratureQCAgent:
    """Runtime Agent 1.

    All external dependencies are injected so the agent is fully unit-
    testable against fakes (`FakeOpenAIClient`, `FakeTavilyClient`,
    `FakeCitationResolver`). The agent is `@dataclass`-shaped because it
    is constructed once per request from the FastAPI dependency layer.
    """

    openai: AbstractOpenAIClient
    tavily: AbstractTavilyClient
    citation_resolver: AbstractCitationResolver
    source_tiers: SourceTiersConfig
    settings: Settings | None = None

    async def run(self, *, hypothesis: str, request_id: str) -> LiteratureQCResult:
        cfg = self.settings or get_settings()
        role = load_role(_ROLE_FILE)
        versions = prompt_versions()
        start = time.perf_counter()

        keyword_query = await self._extract_keywords(hypothesis, cfg)

        verbatim = await self.tavily.search(
            query=hypothesis,
            include_domains=self.source_tiers.tavily_include_domains(),
            depth="advanced",
            max_results=10,
        )
        keyworded = await self.tavily.search(
            query=keyword_query,
            include_domains=self.source_tiers.tavily_include_domains(),
            depth="advanced",
            max_results=10,
        )
        merged = _merge_hits([verbatim, keyworded])

        kept_hits, tier_0_drops = self._partition_by_tier(merged)

        claim = await self._classify(role, hypothesis, kept_hits, cfg)
        floored = _apply_confidence_floor(claim)

        verified_refs: list[Reference] = []
        for ref_claim in floored.references[: _MAX_REFERENCES * 2]:
            url = str(ref_claim.url)
            tier = self.source_tiers.classify(url)
            if tier is SourceTier.TIER_0_FORBIDDEN:
                tier_0_drops += 1
                continue
            if tier is SourceTier.TIER_3_GENERAL_WEB:
                continue
            candidate = Reference(
                title=ref_claim.title,
                url=ref_claim.url,
                doi=ref_claim.doi,
                why_relevant=ref_claim.why_relevant,
                tier=tier,
            )
            outcome = await self.citation_resolver.resolve(candidate)
            if outcome.tier_0_drop:
                tier_0_drops += 1
                continue
            if outcome.reference is None or not outcome.reference.verified:
                continue
            verified_refs.append(outcome.reference)
            if len(verified_refs) >= _MAX_REFERENCES:
                break

        novelty = floored.novelty
        if (
            novelty in {NoveltyLabel.EXACT_MATCH, NoveltyLabel.SIMILAR_WORK_EXISTS}
            and not verified_refs
        ):
            novelty = (
                NoveltyLabel.SIMILAR_WORK_EXISTS
                if novelty is NoveltyLabel.EXACT_MATCH
                else NoveltyLabel.NOT_FOUND
            )

        latency_ms = int((time.perf_counter() - start) * 1000)
        result = LiteratureQCResult(
            novelty=novelty,
            references=verified_refs,
            confidence=_bucket_confidence(floored.confidence),
            tier_0_drops=tier_0_drops,
        )

        emit_agent_call_complete(
            _AGENT_NAME,
            model=cfg.OPENAI_MODEL_LITERATURE_QC,
            prompt_hash=versions[_ROLE_FILE],
            prompt_tokens=_total_prompt_tokens(claim_usage=claim, role=role),
            completion_tokens=claim.usage.completion_tokens,
            latency_ms=latency_ms,
            verified_count=len(verified_refs),
            tier_0_drops=tier_0_drops,
            request_id=request_id,
        )
        return result

    async def _extract_keywords(self, hypothesis: str, cfg: Settings) -> str:
        chat_result: ChatResult = await self.openai.chat(
            model=cfg.OPENAI_MODEL_LITERATURE_QC,
            messages=[
                ChatMessage(
                    role="system",
                    content=(
                        "Return 3-6 noun-phrase keywords from the user's "
                        "hypothesis, separated by spaces. No punctuation."
                    ),
                ),
                ChatMessage(role="user", content=hypothesis),
            ],
            temperature=cfg.OPENAI_TEMP_LITERATURE_QC,
            seed=cfg.OPENAI_SEED_LITERATURE_QC,
            max_tokens=80,
        )
        return chat_result.content.strip() or hypothesis

    def _partition_by_tier(self, hits: list[TavilyHit]) -> tuple[list[TavilyHit], int]:
        kept: list[TavilyHit] = []
        drops = 0
        for hit in hits:
            tier = self.source_tiers.classify(str(hit.url))
            if tier is SourceTier.TIER_0_FORBIDDEN:
                drops += 1
                continue
            kept.append(hit)
        return kept, drops

    async def _classify(
        self,
        role: str,
        hypothesis: str,
        hits: list[TavilyHit],
        cfg: Settings,
    ) -> ParsedResult[NoveltyClaim]:
        user_payload = _format_user_payload(hypothesis, hits)
        return await self.openai.parse(
            model=cfg.OPENAI_MODEL_LITERATURE_QC,
            messages=[
                ChatMessage(role="system", content=role),
                ChatMessage(role="user", content=user_payload),
            ],
            response_format=NoveltyClaim,
            temperature=cfg.OPENAI_TEMP_LITERATURE_QC,
            seed=cfg.OPENAI_SEED_LITERATURE_QC,
            max_tokens=cfg.OPENAI_MAX_TOKENS_LITERATURE_QC,
        )


def _format_user_payload(hypothesis: str, hits: list[TavilyHit]) -> str:
    rendered_hits = [
        {
            "title": hit.title,
            "url": str(hit.url),
            "snippet": hit.snippet,
            "score": hit.score,
        }
        for hit in hits
    ]
    return (
        "== HYPOTHESIS ==\n"
        f"{hypothesis}\n\n"
        "== TAVILY RESULTS (Tier 0 already filtered) ==\n"
        f"{rendered_hits}"
    )


def _merge_hits(results: list[TavilySearchResult]) -> list[TavilyHit]:
    seen: set[str] = set()
    merged: list[TavilyHit] = []
    for batch in results:
        for hit in batch.results:
            key = _dedupe_key(str(hit.url))
            if key in seen:
                continue
            seen.add(key)
            merged.append(hit)
            if len(merged) >= _MAX_HITS:
                return merged
    return merged


def _dedupe_key(url: str) -> str:
    return url.lower().rstrip("/")


def _apply_confidence_floor(claim: ParsedResult[NoveltyClaim]) -> NoveltyClaim:
    parsed = claim.parsed
    if parsed.confidence >= 0.5:
        return parsed
    if parsed.novelty is NoveltyLabel.EXACT_MATCH:
        return parsed.model_copy(update={"novelty": NoveltyLabel.SIMILAR_WORK_EXISTS})
    if parsed.novelty is NoveltyLabel.SIMILAR_WORK_EXISTS:
        return parsed.model_copy(update={"novelty": NoveltyLabel.NOT_FOUND})
    return parsed


def _bucket_confidence(value: float) -> str:
    if value >= 0.8:
        return "high"
    if value >= 0.5:
        return "medium"
    return "low"


def _total_prompt_tokens(claim_usage: ParsedResult[NoveltyClaim], role: str) -> int:
    """Best-effort prompt-token accumulator for the structured-log line."""

    return claim_usage.usage.prompt_tokens
