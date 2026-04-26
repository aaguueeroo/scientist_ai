"""Runtime orchestrator (Steps 33 + 43).

Sequences Agent 1 → novelty gate → (if not `exact_match`) Agent 2 →
Agent 3 → `apply_resolvers` → `refuse_if_ungrounded` → MIQE block.

Agent 2 is wired in only when a `feedback_repo` is supplied; if omitted
the orchestrator behaves exactly as it did in Step 33 (empty few-shots
into Agent 3). Production wiring always supplies the repo.
"""

from __future__ import annotations

import time
from dataclasses import dataclass

import structlog

from app.agents.experiment_planner import ExperimentPlannerAgent
from app.agents.feedback_relevance import FeedbackRelevanceAgent
from app.agents.literature_qc import LiteratureQCAgent
from app.clients.openai_client import AbstractOpenAIClient
from app.clients.tavily_client import AbstractTavilyClient
from app.config.settings import Settings, get_settings
from app.config.source_tiers import SourceTiersConfig
from app.prompts.loader import prompt_versions
from app.runtime.novelty_gate import StopWithQC, decide
from app.runtime.pipeline_state import PipelineState
from app.schemas.experiment_plan import GroundingSummary
from app.schemas.feedback import FewShotExample
from app.schemas.literature_qc import LiteratureQCResult
from app.schemas.responses import GeneratePlanResponse
from app.storage.feedback_repo import FeedbackRepo
from app.verification.catalog_resolver import AbstractCatalogResolver
from app.verification.citation_resolver import AbstractCitationResolver
from app.verification.grounding import apply_resolvers, refuse_if_ungrounded
from app.verification.miqe_checklist import populate_miqe_if_qpcr

_log = structlog.get_logger("pipeline")


@dataclass
class Orchestrator:
    """Runtime orchestrator that ties the agents and resolvers together."""

    openai: AbstractOpenAIClient
    tavily: AbstractTavilyClient
    citation_resolver: AbstractCitationResolver
    catalog_resolver: AbstractCatalogResolver
    source_tiers: SourceTiersConfig
    settings: Settings | None = None
    feedback_repo: FeedbackRepo | None = None

    async def run(
        self,
        *,
        hypothesis: str,
        request_id: str,
        precached_literature_qc: LiteratureQCResult | None = None,
    ) -> GeneratePlanResponse:
        cfg = self.settings or get_settings()
        _log.info(
            "pipeline.begin",
            request_id=request_id,
            hypothesis_length=len(hypothesis),
            precached_literature_qc=precached_literature_qc is not None,
        )
        t_lit = time.perf_counter()

        if precached_literature_qc is not None:
            qc = precached_literature_qc
            _log.info(
                "pipeline.literature_qc.precached",
                request_id=request_id,
                novelty=qc.novelty.value,
                reference_count=len(qc.references),
            )
            _log.debug(
                "pipeline.literature_qc.step_ms",
                request_id=request_id,
                phase="precached_load",
                elapsed_ms=int((time.perf_counter() - t_lit) * 1000),
            )
        else:
            qc_agent = LiteratureQCAgent(
                openai=self.openai,
                tavily=self.tavily,
                citation_resolver=self.citation_resolver,
                source_tiers=self.source_tiers,
                settings=cfg,
            )
            qc = await qc_agent.run(hypothesis=hypothesis, request_id=request_id)
            _log.info(
                "pipeline.literature_qc.done",
                request_id=request_id,
                novelty=qc.novelty.value,
                reference_count=len(qc.references),
            )
            _log.debug(
                "pipeline.literature_qc.step_ms",
                request_id=request_id,
                phase="agent_run",
                elapsed_ms=int((time.perf_counter() - t_lit) * 1000),
            )

        t_gate0 = time.perf_counter()
        outcome = decide(qc.novelty)
        if isinstance(outcome, StopWithQC):
            _log.info(
                "pipeline.novelty_gate.stop",
                request_id=request_id,
                reason="exact_match",
            )
            _log.debug(
                "pipeline.novelty_gate.step_ms",
                request_id=request_id,
                elapsed_ms=int((time.perf_counter() - t_gate0) * 1000),
            )
            return GeneratePlanResponse(
                plan_id=None,
                request_id=request_id,
                qc=qc,
                plan=None,
                grounding_summary=GroundingSummary(
                    verified_count=sum(1 for r in qc.references if r.verified),
                    unverified_count=sum(1 for r in qc.references if not r.verified),
                    tier_0_drops=qc.tier_0_drops,
                ),
                prompt_versions=prompt_versions(),
            )

        _log.debug(
            "pipeline.novelty_gate.step_ms",
            request_id=request_id,
            elapsed_ms=int((time.perf_counter() - t_gate0) * 1000),
        )

        t_fb0 = time.perf_counter()
        few_shots: list[FewShotExample] = []
        if self.feedback_repo is not None and await self.feedback_repo.count() > 0:
            agent_2 = FeedbackRelevanceAgent(openai=self.openai, settings=cfg)
            few_shots = await agent_2.run(
                hypothesis=hypothesis,
                repo=self.feedback_repo,
                request_id=request_id,
            )
            _log.info(
                "pipeline.feedback_relevance.done",
                request_id=request_id,
                few_shot_count=len(few_shots),
            )
            _log.debug(
                "pipeline.feedback_relevance.step_ms",
                request_id=request_id,
                elapsed_ms=int((time.perf_counter() - t_fb0) * 1000),
            )
        else:
            _log.debug("pipeline.feedback_relevance.skip", request_id=request_id)
            _log.debug(
                "pipeline.feedback_relevance.step_ms",
                request_id=request_id,
                elapsed_ms=int((time.perf_counter() - t_fb0) * 1000),
            )

        t_plan0 = time.perf_counter()
        state = PipelineState(
            request_id=request_id,
            hypothesis=hypothesis,
            qc_result=qc,
            few_shot_examples=few_shots,
        )
        planner = ExperimentPlannerAgent(openai=self.openai, settings=cfg)
        plan = await planner.run(state=state)
        _log.info(
            "pipeline.experiment_planner.done",
            request_id=request_id,
            plan_id=plan.plan_id,
        )
        _log.debug(
            "pipeline.experiment_planner.step_ms",
            request_id=request_id,
            elapsed_ms=int((time.perf_counter() - t_plan0) * 1000),
        )

        t_gr0 = time.perf_counter()
        grounded = await apply_resolvers(
            plan,
            citation_resolver=self.citation_resolver,
            catalog_resolver=self.catalog_resolver,
        )
        # account for Agent 1's own Tier-0 drops in the per-request total
        grounded = grounded.model_copy(
            update={
                "grounding_summary": grounded.grounding_summary.model_copy(
                    update={
                        "tier_0_drops": grounded.grounding_summary.tier_0_drops + qc.tier_0_drops,
                    }
                )
            }
        )
        refuse_if_ungrounded(grounded, grounded.grounding_summary)
        _log.info(
            "pipeline.grounding.done",
            request_id=request_id,
            verified=grounded.grounding_summary.verified_count,
            unverified=grounded.grounding_summary.unverified_count,
        )
        _log.debug(
            "pipeline.grounding.step_ms",
            request_id=request_id,
            elapsed_ms=int((time.perf_counter() - t_gr0) * 1000),
        )

        with_miqe = populate_miqe_if_qpcr(grounded)

        _log.info("pipeline.complete", request_id=request_id, plan_id=with_miqe.plan_id)
        return GeneratePlanResponse(
            plan_id=with_miqe.plan_id,
            request_id=request_id,
            qc=qc,
            plan=with_miqe,
            grounding_summary=with_miqe.grounding_summary,
            prompt_versions=prompt_versions(),
        )
