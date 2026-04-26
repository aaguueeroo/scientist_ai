"""Runtime Agent 1 — Literature QC.

Pipeline:
1. Build Q1 (verbatim hypothesis) and Q2 (LLM-extracted keywords).
2. Run two Tavily searches (the Tavily layer enforces include_domains).
3. Merge + deduplicate results; drop Tier-0 hits before any LLM call.
4. Ask gpt-4.1-mini (role: literature_qc.md, structured output) for the
   novelty label + candidate references + numeric confidence.
5. Apply the confidence floor (research §6.5).
6. Run each candidate reference through the citation resolver. The
   LLM never marks a reference verified. If the HTTP resolver does not
   confirm the row but the same work has a Tavily relevance **score** above
   0.6, treat it as verified anyway (Tavily-only verification).
7. Deduplicate by normalized DOI (or host+path for publishers); skip
   repeated LLM rows that point to the same work. Cap at 5 references.
8. If no verified row yet, backfill from merged Tavily hits (score>0.6) before
   unverified similarity suggestions.
9. Emit one structured log line with the per-request contract keys.
"""

from __future__ import annotations

import time
from dataclasses import dataclass
from typing import Final, Literal
from urllib.parse import unquote, urlparse

import structlog
from pydantic import Field

from app.clients.openai_client import (
    AbstractOpenAIClient,
    ChatMessage,
    ChatResult,
    ParsedResult,
)
from app.api.errors import TavilyUnavailable
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
from app.schemas.openai_structured_model import OpenAIStructuredModel
from app.verification.citation_resolver import AbstractCitationResolver

_AGENT_NAME = "literature_qc"
_ROLE_FILE = "literature_qc.md"
_MAX_REFERENCES = 5
# Per Tavily request: API allows up to 20; we use the ceiling so both verbatim + keyword
# searches can contribute every hit (see `_merge_hits` — no cap after dedupe).
_TAVILY_MAX_RESULTS: Final[int] = 20
# Tavily returns a per-hit relevance score in [0,1]. Above this floor we accept
# the result as "verified" even when the HTTP citation resolver does not.
_TAVILY_SCORE_VERIFIED_FLOOR: Final[float] = 0.6

_log = structlog.get_logger("app")


def _log_short_url(url: str, max_len: int = 120) -> str:
    s = (url or "").replace("\n", " ")
    if len(s) <= max_len:
        return s
    return f"{s[: max_len - 3]}..."


class ReferenceClaim(OpenAIStructuredModel):
    """A reference proposed by the LLM (unverified, untiered).

    ``url`` is a ``str`` (not :class:`pydantic.HttpUrl`) so
    :meth:`openai.chat.completions.parse` receives a JSON Schema with no
    ``format: uri`` — OpenAI structured outputs reject that format keyword.
    """

    title: str = Field(min_length=1, max_length=500)
    url: str = Field(min_length=1, max_length=2048)
    doi: str | None = None
    why_relevant: str = Field(min_length=1, max_length=400)


class NoveltyClaim(OpenAIStructuredModel):
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

        def _ms() -> int:
            return int((time.perf_counter() - start) * 1000)

        _log.info(
            "app.literature_qc.begin",
            request_id=request_id,
            step="start",
            elapsed_ms=_ms(),
        )

        _log.info(
            "app.literature_qc.step",
            request_id=request_id,
            step="openai_keywords_begin",
            elapsed_ms=_ms(),
        )
        keyword_query = await self._extract_keywords(hypothesis, cfg)
        _log.info(
            "app.literature_qc.step",
            request_id=request_id,
            step="openai_keywords_done",
            keyword_len=len(keyword_query),
            preview=keyword_query[:200],
            elapsed_ms=_ms(),
        )

        _log.info(
            "app.literature_qc.step",
            request_id=request_id,
            step="tavily_verbatim_begin",
            elapsed_ms=_ms(),
        )
        verbatim = await self.tavily.search(
            query=hypothesis,
            include_domains=self.source_tiers.tavily_include_domains(),
            depth="advanced",
            max_results=_TAVILY_MAX_RESULTS,
        )
        _log.info(
            "app.literature_qc.step",
            request_id=request_id,
            step="tavily_verbatim_done",
            hit_count=len(verbatim.results),
            elapsed_ms=_ms(),
        )
        _log.info(
            "app.literature_qc.step",
            request_id=request_id,
            step="tavily_keyword_begin",
            elapsed_ms=_ms(),
        )
        keyworded = await self.tavily.search(
            query=keyword_query,
            include_domains=self.source_tiers.tavily_include_domains(),
            depth="advanced",
            max_results=_TAVILY_MAX_RESULTS,
        )
        _log.info(
            "app.literature_qc.step",
            request_id=request_id,
            step="tavily_keyword_done",
            hit_count=len(keyworded.results),
            elapsed_ms=_ms(),
        )
        merged = _merge_hits([verbatim, keyworded])
        tavily_scores = _max_tavily_score_by_work(verbatim, keyworded)
        _log.info(
            "app.literature_qc.step",
            request_id=request_id,
            step="tavily_merged",
            merged_hit_count=len(merged),
            elapsed_ms=_ms(),
        )

        kept_hits, tier_0_drops = self._partition_by_tier(merged)
        _log.info(
            "app.literature_qc.step",
            request_id=request_id,
            step="partition_tier",
            kept_for_llm=len(kept_hits),
            tier_0_drops_initial=tier_0_drops,
            elapsed_ms=_ms(),
        )

        _log.info(
            "app.literature_qc.step",
            request_id=request_id,
            step="openai_classify_begin",
            elapsed_ms=_ms(),
        )
        claim = await self._classify(role, hypothesis, kept_hits, cfg)
        _log.info(
            "app.literature_qc.step",
            request_id=request_id,
            step="openai_classify_done",
            novelty=claim.parsed.novelty.value,
            ref_claims=len(claim.parsed.references),
            elapsed_ms=_ms(),
        )
        floored = _apply_confidence_floor(claim)

        verified_refs: list[Reference] = []
        seen_claim_keys: set[str] = set()
        seen_verified_keys: set[str] = set()
        cr_index = 0
        for ref_claim in floored.references[: _MAX_REFERENCES * 2]:
            claim_key = _reference_claim_identity_key(ref_claim)
            if claim_key in seen_claim_keys:
                continue
            seen_claim_keys.add(claim_key)

            url = str(ref_claim.url)
            tier = self.source_tiers.classify(url)
            t_score = _tavily_score_for_url(tavily_scores, url)
            if tier is SourceTier.TIER_0_FORBIDDEN:
                tier_0_drops += 1
                continue
            if tier is SourceTier.TIER_3_GENERAL_WEB:
                if _tavily_relevance_strong(t_score):
                    t3 = Reference(
                        title=ref_claim.title[:500],
                        url=ref_claim.url,
                        doi=ref_claim.doi,
                        why_relevant=ref_claim.why_relevant,
                        tier=tier,
                        verified=True,
                        confidence="high" if t_score >= 0.8 else "medium",
                        verification_url=url,
                        is_similarity_suggestion=False,
                    )
                    out_key = _reference_identity_key(t3)
                    if out_key not in seen_verified_keys:
                        _log.info(
                            "app.literature_qc.tavily_score_verified",
                            request_id=request_id,
                            url=_log_short_url(url),
                            tavily_score=t_score,
                            path="tier3_claim",
                        )
                        seen_verified_keys.add(out_key)
                        verified_refs.append(t3)
                        if len(verified_refs) >= _MAX_REFERENCES:
                            break
                continue
            candidate = Reference(
                title=ref_claim.title,
                url=ref_claim.url,
                doi=ref_claim.doi,
                why_relevant=ref_claim.why_relevant,
                tier=tier,
            )
            cr_index += 1
            _log.info(
                "app.literature_qc.citation_try",
                request_id=request_id,
                attempt=cr_index,
                url=_log_short_url(url),
                has_doi=bool(ref_claim.doi),
                tier=tier.value,
                tavily_score=t_score,
                elapsed_ms=_ms(),
            )
            outcome = await self.citation_resolver.resolve(candidate)
            _log.info(
                "app.literature_qc.citation_result",
                request_id=request_id,
                attempt=cr_index,
                url=_log_short_url(url),
                verified=bool(
                    outcome.reference and outcome.reference.verified,
                ),
                tier_0_drop=outcome.tier_0_drop,
                elapsed_ms=_ms(),
            )
            if outcome.tier_0_drop:
                tier_0_drops += 1
                continue
            if outcome.reference and outcome.reference.verified:
                resolved = outcome.reference
            elif _tavily_relevance_strong(t_score):
                base = outcome.reference if outcome.reference is not None else candidate
                _log.info(
                    "app.literature_qc.tavily_score_verified",
                    request_id=request_id,
                    url=_log_short_url(url),
                    tavily_score=t_score,
                    path="resolver_tavily_override",
                )
                vurl = url
                if outcome.reference and outcome.reference.verification_url:
                    vurl = outcome.reference.verification_url
                resolved = _promote_reference_with_tavily_score(
                    base, tavily_score=t_score, verification_url=vurl
                )
            else:
                continue
            out_key = _reference_identity_key(resolved)
            if out_key in seen_verified_keys:
                continue
            seen_verified_keys.add(out_key)
            verified_refs.append(resolved)
            if len(verified_refs) >= _MAX_REFERENCES:
                break

        if not verified_refs:
            verified_refs.extend(
                _backfill_verified_references_from_tavily(
                    merged,
                    self.source_tiers,
                    tavily_scores,
                    seen_verified_keys,
                    max_add=_MAX_REFERENCES,
                )
            )

        similarity_suggestion: Reference | None = None
        if not verified_refs:
            similarity_suggestion = _pick_similarity_suggestion(
                self.source_tiers, kept_hits, merged, floored, tavily_scores
            )
            if similarity_suggestion is None:
                _log.info(
                    "app.literature_qc.tavily_web_wide_fallback",
                    request_id=request_id,
                    step="search_web_wide",
                    elapsed_ms=_ms(),
                )
                try:
                    web_wide = await self.tavily.search_web_wide(
                        query=keyword_query,
                        depth="advanced",
                        max_results=_TAVILY_MAX_RESULTS,
                    )
                except TavilyUnavailable as err:
                    _log.warning(
                        "app.literature_qc.tavily_web_wide_failed",
                        request_id=request_id,
                        err=repr(err),
                    )
                else:
                    w = web_wide.results
                    for hit in w:
                        _ingest_tavily_hit_score(tavily_scores, hit)
                    if not verified_refs:
                        verified_refs.extend(
                            _backfill_verified_references_from_tavily(
                                w,
                                self.source_tiers,
                                tavily_scores,
                                seen_verified_keys,
                                max_add=_MAX_REFERENCES,
                            )
                        )
                    if not verified_refs:
                        similarity_suggestion = _pick_similarity_suggestion(
                            self.source_tiers, w, w, floored, tavily_scores
                        )
            if similarity_suggestion is not None:
                _log.info(
                    "app.literature_qc.similarity_suggestion",
                    request_id=request_id,
                    url=_log_short_url(str(similarity_suggestion.url)),
                )

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
            similarity_suggestion=similarity_suggestion,
            confidence=_bucket_confidence(floored.confidence),
            tier_0_drops=tier_0_drops,
        )

        _log.info(
            "app.literature_qc.complete",
            request_id=request_id,
            step="agent_run_done",
            verified_ref_count=len(verified_refs),
            final_novelty=novelty.value,
            total_elapsed_ms=latency_ms,
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
    """Dedupe by normalized work id (DOI, else host+path; query ignored)."""

    seen: set[str] = set()
    merged: list[TavilyHit] = []
    for batch in results:
        for hit in batch.results:
            key = _work_identity_from_url(str(hit.url))
            if key in seen:
                continue
            seen.add(key)
            merged.append(hit)
    return merged


def _max_tavily_score_by_work(
    *batches: TavilySearchResult,
) -> dict[str, float]:
    """For each work id, keep the max Tavily relevance score (verbatim + keyword searches)."""

    out: dict[str, float] = {}
    for batch in batches:
        for hit in batch.results:
            k = _work_identity_from_url(str(hit.url))
            out[k] = max(out.get(k, 0.0), float(hit.score))
    return out


def _tavily_score_for_url(tavily_scores: dict[str, float], url: str) -> float:
    return tavily_scores.get(_work_identity_from_url(url), 0.0)


def _tavily_relevance_strong(score: float) -> bool:
    return score > _TAVILY_SCORE_VERIFIED_FLOOR


def _ingest_tavily_hit_score(tavily_scores: dict[str, float], hit: TavilyHit) -> None:
    k = _work_identity_from_url(str(hit.url))
    tavily_scores[k] = max(tavily_scores.get(k, 0.0), float(hit.score))


def _promote_reference_with_tavily_score(
    base: Reference,
    *,
    tavily_score: float,
    verification_url: str,
) -> Reference:
    return base.model_copy(
        update={
            "verified": True,
            "is_similarity_suggestion": False,
            "confidence": "high" if tavily_score >= 0.8 else "medium",
            "verification_url": verification_url,
        }
    )


def _backfill_verified_references_from_tavily(
    hits: list[TavilyHit],
    source_tiers: SourceTiersConfig,
    tavily_scores: dict[str, float],
    seen_verified_keys: set[str],
    *,
    max_add: int,
) -> list[Reference]:
    """Add verified rows from high-scoring Tavily hits not already in ``seen_verified_keys``."""

    out: list[Reference] = []
    for hit in sorted(hits, key=lambda h: h.score, reverse=True):
        u = str(hit.url)
        if source_tiers.classify(u) is SourceTier.TIER_0_FORBIDDEN:
            continue
        wk = _work_identity_from_url(u)
        if wk in seen_verified_keys:
            continue
        t_score = tavily_scores.get(wk, 0.0)
        if not _tavily_relevance_strong(t_score):
            continue
        ref = _reference_from_tavily_hit_tavily_verified(
            hit, t_score, source_tiers.classify(u)
        )
        seen_verified_keys.add(_reference_identity_key(ref))
        out.append(ref)
        if len(out) >= max_add:
            break
    return out


def _reference_from_tavily_hit_tavily_verified(
    hit: TavilyHit, tavily_score: float, tier: SourceTier
) -> Reference:
    u = str(hit.url)
    why = (hit.snippet or hit.title or "")[:400]
    return Reference(
        title=hit.title[:500],
        url=u,
        doi=None,
        why_relevant=why,
        tier=tier,
        verified=True,
        confidence="high" if tavily_score >= 0.8 else "medium",
        verification_url=u,
        is_similarity_suggestion=False,
    )


def _pick_similarity_suggestion(
    source_tiers: SourceTiersConfig,
    kept_hits: list[TavilyHit],
    merged: list[TavilyHit],
    floored: NoveltyClaim,
    tavily_scores: dict[str, float] | None = None,
) -> Reference | None:
    """If there are no verified references, pick one best-effort similar link.

    Order: best-scoring peer-allowed Tavily hit, then any non-forbidden merged
    hit, then a non-forbidden LLM claim. Not run through the HTTP resolver.
    Hits with Tavily relevance **above** 0.6 are not returned here; those are
    treated as verified elsewhere.
    """

    ts = tavily_scores or {}

    def _score_for(hit: TavilyHit) -> float:
        wk = _work_identity_from_url(str(hit.url))
        return max(ts.get(wk, 0.0), float(hit.score))

    def _from_tavily_hit_unverified(hit: TavilyHit) -> Reference:
        u = str(hit.url)
        why = (hit.snippet or hit.title or "")[:400]
        return Reference(
            title=hit.title[:500],
            url=u,
            doi=None,
            why_relevant=why,
            tier=source_tiers.classify(u),
            verified=False,
            confidence="low",
            is_similarity_suggestion=True,
        )

    for hit in sorted(kept_hits, key=lambda h: h.score, reverse=True):
        if _tavily_relevance_strong(_score_for(hit)):
            continue
        return _from_tavily_hit_unverified(hit)
    for hit in sorted(merged, key=lambda h: h.score, reverse=True):
        u = str(hit.url)
        if source_tiers.classify(u) is SourceTier.TIER_0_FORBIDDEN:
            continue
        if _tavily_relevance_strong(_score_for(hit)):
            continue
        return _from_tavily_hit_unverified(hit)
    for claim in floored.references:
        u = str(claim.url)
        tid = source_tiers.classify(u)
        if tid is SourceTier.TIER_0_FORBIDDEN:
            continue
        return Reference(
            title=claim.title,
            url=claim.url,
            doi=claim.doi,
            why_relevant=claim.why_relevant,
            tier=tid,
            verified=False,
            confidence="low",
            is_similarity_suggestion=True,
        )
    return None


def _normalize_doi(doi: str | None) -> str | None:
    if doi is None:
        return None
    s = unquote(doi.strip())
    if not s:
        return None
    lower = s.lower()
    for prefix in (
        "https://doi.org/",
        "http://doi.org/",
        "https://dx.doi.org/",
        "http://dx.doi.org/",
    ):
        if lower.startswith(prefix):
            lower = lower[len(prefix) :]
            break
    return lower.rstrip("/.").lower() or None


def _work_identity_from_url(url: str) -> str:
    """Stable key for the same work across URL variants (doi.org, www, UTM, etc.)."""

    p = urlparse((url or "").strip())
    host = (p.netloc or "").lower()
    if host.startswith("www."):
        host = host[4:]
    raw_path = p.path or "/"
    if "doi.org" in host:
        d = _normalize_doi(raw_path.lstrip("/"))
        if d:
            return f"doi:{d}"
    path = unquote(raw_path)
    if path not in ("/", "") and path.endswith("/"):
        path = path.rstrip("/")
    path = path.lower()
    return f"url:{host}{path}"


def _reference_identity_key(ref: Reference) -> str:
    d = _normalize_doi(ref.doi)
    if d:
        return f"doi:{d}"
    return _work_identity_from_url(str(ref.url))


def _reference_claim_identity_key(claim: ReferenceClaim) -> str:
    d = _normalize_doi(claim.doi)
    if d:
        return f"doi:{d}"
    return _work_identity_from_url(str(claim.url))


def _apply_confidence_floor(claim: ParsedResult[NoveltyClaim]) -> NoveltyClaim:
    parsed = claim.parsed
    if parsed.confidence >= 0.5:
        return parsed
    if parsed.novelty is NoveltyLabel.EXACT_MATCH:
        return parsed.model_copy(update={"novelty": NoveltyLabel.SIMILAR_WORK_EXISTS})
    if parsed.novelty is NoveltyLabel.SIMILAR_WORK_EXISTS:
        return parsed.model_copy(update={"novelty": NoveltyLabel.NOT_FOUND})
    return parsed


def _bucket_confidence(value: float) -> Literal["high", "medium", "low"]:
    if value >= 0.8:
        return "high"
    if value >= 0.5:
        return "medium"
    return "low"


def _total_prompt_tokens(claim_usage: ParsedResult[NoveltyClaim], role: str) -> int:
    """Best-effort prompt-token accumulator for the structured-log line."""

    return claim_usage.usage.prompt_tokens
