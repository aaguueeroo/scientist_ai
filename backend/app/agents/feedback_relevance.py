"""Runtime Agent 2 — Feedback relevance.

Pipeline (per `docs/research.md` §7):

1. Domain extraction. One `gpt-4.1-mini` call with role
   `feedback_relevance.md`. Schema-enforced output: a single
   `DomainTag` value.
2. Store query. `FeedbackRepo.find_relevant(domain_tag, k=20)` returns
   the most-recent matching corrections.
3. Relevance rerank. A second `gpt-4.1-mini` call scores each
   correction in `[0.0, 1.0]`. Top 5 survive.
4. Few-shot shaping. Surviving corrections are returned as
   `FewShotExample` instances (Agent 3 input).

The role string is loaded from `app/prompts/feedback_relevance.md` and
is **always** the OpenAI `system` message; user content (hypothesis +
candidate corrections) is **always** the `user` message. Nothing the
caller passes is ever concatenated into the role string.
"""

from __future__ import annotations

import time
from dataclasses import dataclass

from pydantic import BaseModel, Field

from app.clients.openai_client import (
    AbstractOpenAIClient,
    ChatMessage,
    ParsedResult,
)
from app.config.settings import Settings, get_settings
from app.observability.logging import emit_agent_call_complete
from app.prompts.loader import load_role, prompt_versions
from app.schemas.feedback import DomainTag, FewShotExample
from app.storage.feedback_repo import FeedbackRepo

_AGENT_NAME = "feedback_relevance"
_ROLE_FILE = "feedback_relevance.md"
_CANDIDATE_LIMIT = 20
_RESULT_LIMIT = 5


class DomainTagClaim(BaseModel):
    """Closed-enum domain tag returned by the first LLM call."""

    domain_tag: DomainTag


class RelevanceItem(BaseModel):
    """One score in the rerank step."""

    feedback_id: str = Field(min_length=1, max_length=64)
    score: float = Field(ge=0.0, le=1.0)


class RelevanceClaim(BaseModel):
    """The structured output for the second LLM call."""

    items: list[RelevanceItem] = Field(default_factory=list)


@dataclass
class FeedbackRelevanceAgent:
    """Runtime Agent 2.

    The repo is injected at `run()` time (not on the dataclass) because
    the orchestrator reuses the same agent instance across requests but
    the repo is shared via FastAPI's app state.
    """

    openai: AbstractOpenAIClient
    settings: Settings | None = None

    async def extract_domain(
        self,
        *,
        hypothesis: str,
        request_id: str,
    ) -> DomainTag:
        """Run only the domain-extraction LLM call.

        Used by `POST /feedback` when the caller omits `domain_tag` so the
        route can avoid Agent 2's heavier rerank step. Emits a single
        structured log line with the contract keys.
        """

        cfg = self.settings or get_settings()
        role = load_role(_ROLE_FILE)
        versions = prompt_versions()
        start = time.perf_counter()

        result = await self._extract_domain(role, hypothesis, cfg)

        latency_ms = int((time.perf_counter() - start) * 1000)
        emit_agent_call_complete(
            _AGENT_NAME,
            model=cfg.OPENAI_MODEL_FEEDBACK_RELEVANCE,
            prompt_hash=versions[_ROLE_FILE],
            prompt_tokens=result.usage.prompt_tokens,
            completion_tokens=result.usage.completion_tokens,
            latency_ms=latency_ms,
            verified_count=0,
            tier_0_drops=0,
            request_id=request_id,
        )
        return result.parsed.domain_tag

    async def run(
        self,
        *,
        hypothesis: str,
        repo: FeedbackRepo,
        request_id: str,
    ) -> list[FewShotExample]:
        cfg = self.settings or get_settings()
        role = load_role(_ROLE_FILE)
        versions = prompt_versions()
        start = time.perf_counter()

        domain_result = await self._extract_domain(role, hypothesis, cfg)
        domain_tag = domain_result.parsed.domain_tag

        candidates = await repo.find_relevant(domain_tag=domain_tag, k=_CANDIDATE_LIMIT)
        prompt_tokens = domain_result.usage.prompt_tokens
        completion_tokens = domain_result.usage.completion_tokens
        examples: list[FewShotExample] = []

        if candidates:
            rerank_result = await self._rerank(role, hypothesis, candidates, cfg)
            prompt_tokens += rerank_result.usage.prompt_tokens
            completion_tokens += rerank_result.usage.completion_tokens
            examples = _select_top_k(candidates, rerank_result.parsed.items)

        latency_ms = int((time.perf_counter() - start) * 1000)
        emit_agent_call_complete(
            _AGENT_NAME,
            model=cfg.OPENAI_MODEL_FEEDBACK_RELEVANCE,
            prompt_hash=versions[_ROLE_FILE],
            prompt_tokens=prompt_tokens,
            completion_tokens=completion_tokens,
            latency_ms=latency_ms,
            verified_count=len(examples),
            tier_0_drops=0,
            request_id=request_id,
        )
        return examples

    async def _extract_domain(
        self,
        role: str,
        hypothesis: str,
        cfg: Settings,
    ) -> ParsedResult[DomainTagClaim]:
        user_payload = (
            "== HYPOTHESIS ==\n"
            f"{hypothesis}\n\n"
            "== TASK ==\n"
            "Pick the single best domain_tag for the hypothesis above."
        )
        return await self.openai.parse(
            model=cfg.OPENAI_MODEL_FEEDBACK_RELEVANCE,
            messages=[
                ChatMessage(role="system", content=role),
                ChatMessage(role="user", content=user_payload),
            ],
            response_format=DomainTagClaim,
            temperature=cfg.OPENAI_TEMP_FEEDBACK_RELEVANCE,
            seed=cfg.OPENAI_SEED_FEEDBACK_DOMAIN,
            max_tokens=cfg.OPENAI_MAX_TOKENS_FEEDBACK_DOMAIN,
        )

    async def _rerank(
        self,
        role: str,
        hypothesis: str,
        candidates: list[FewShotExample],
        cfg: Settings,
    ) -> ParsedResult[RelevanceClaim]:
        rendered_candidates = [
            {
                "feedback_id": f"cand-{idx:03d}",
                "corrected_field": cand.corrected_field,
                "before": cand.before,
                "after": cand.after,
                "reason": cand.reason,
                "domain_tag": cand.domain_tag.value,
            }
            for idx, cand in enumerate(candidates)
        ]
        user_payload = (
            "== HYPOTHESIS ==\n"
            f"{hypothesis}\n\n"
            "== CANDIDATES ==\n"
            f"{rendered_candidates}\n\n"
            "== TASK ==\n"
            "Score each candidate's relevance to the hypothesis in [0.0, 1.0]."
        )
        return await self.openai.parse(
            model=cfg.OPENAI_MODEL_FEEDBACK_RELEVANCE,
            messages=[
                ChatMessage(role="system", content=role),
                ChatMessage(role="user", content=user_payload),
            ],
            response_format=RelevanceClaim,
            temperature=cfg.OPENAI_TEMP_FEEDBACK_RELEVANCE,
            seed=cfg.OPENAI_SEED_FEEDBACK_RERANK,
            max_tokens=cfg.OPENAI_MAX_TOKENS_FEEDBACK_RERANK,
        )


def _select_top_k(
    candidates: list[FewShotExample],
    scored: list[RelevanceItem],
) -> list[FewShotExample]:
    """Pair scored items back to candidates by position; keep top 5."""

    pairs: list[tuple[FewShotExample, float]] = []
    score_by_index: dict[int, float] = {}
    for item in scored:
        if not item.feedback_id.startswith("cand-"):
            continue
        try:
            idx = int(item.feedback_id.removeprefix("cand-"))
        except ValueError:
            continue
        if 0 <= idx < len(candidates):
            score_by_index[idx] = item.score

    for idx, candidate in enumerate(candidates):
        if idx not in score_by_index:
            continue
        score = score_by_index[idx]
        pairs.append((candidate.model_copy(update={"relevance_score": score}), score))

    pairs.sort(key=lambda pair: pair[1], reverse=True)
    return [example for example, _ in pairs[:_RESULT_LIMIT]]
