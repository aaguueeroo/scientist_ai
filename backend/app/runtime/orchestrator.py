"""Runtime orchestrator (Steps 33 + 43).

Sequences Agent 1 → novelty gate → (if not `exact_match`) Agent 2 →
Agent 3 → `apply_resolvers` → `refuse_if_ungrounded` → MIQE block.

Agent 2 is wired in only when a `feedback_repo` is supplied; if omitted
the orchestrator behaves exactly as it did in Step 33 (empty few-shots
into Agent 3). Production wiring always supplies the repo.
"""

from __future__ import annotations

from dataclasses import dataclass

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
from app.schemas.responses import GeneratePlanResponse
from app.storage.feedback_repo import FeedbackRepo
from app.verification.catalog_resolver import AbstractCatalogResolver
from app.verification.citation_resolver import AbstractCitationResolver
from app.verification.grounding import apply_resolvers, refuse_if_ungrounded
from app.verification.miqe_checklist import populate_miqe_if_qpcr


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

    async def run(self, *, hypothesis: str, request_id: str) -> GeneratePlanResponse:
        cfg = self.settings or get_settings()

        qc_agent = LiteratureQCAgent(
            openai=self.openai,
            tavily=self.tavily,
            citation_resolver=self.citation_resolver,
            source_tiers=self.source_tiers,
            settings=cfg,
        )
        qc = await qc_agent.run(hypothesis=hypothesis, request_id=request_id)

        outcome = decide(qc.novelty)
        if isinstance(outcome, StopWithQC):
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

        few_shots: list[FewShotExample] = []
        if self.feedback_repo is not None and await self.feedback_repo.count() > 0:
            agent_2 = FeedbackRelevanceAgent(openai=self.openai, settings=cfg)
            few_shots = await agent_2.run(
                hypothesis=hypothesis,
                repo=self.feedback_repo,
                request_id=request_id,
            )

        state = PipelineState(
            request_id=request_id,
            hypothesis=hypothesis,
            qc_result=qc,
            few_shot_examples=few_shots,
        )
        planner = ExperimentPlannerAgent(openai=self.openai, settings=cfg)
        plan = await planner.run(state=state)

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

        with_miqe = populate_miqe_if_qpcr(grounded)

        return GeneratePlanResponse(
            plan_id=with_miqe.plan_id,
            request_id=request_id,
            qc=qc,
            plan=with_miqe,
            grounding_summary=with_miqe.grounding_summary,
            prompt_versions=prompt_versions(),
        )
