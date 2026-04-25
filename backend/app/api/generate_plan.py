"""`POST /generate-plan` route.

Step 25 implemented the QC-only short-circuit. Step 34 replaces the 501
placeholder for the `continue` branch with a full orchestrator call: it
runs Agent 1 → novelty gate → (if not `exact_match`) Agent 3 → grounding
resolvers → MIQE block, returning the populated `GeneratePlanResponse`.
Errors (`grounding_failed_refused`, `structured_output_invalid`,
`cost_ceiling_exceeded`, …) propagate to the central exception handlers.
"""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Request

from app.api.deps import (
    get_catalog_resolver,
    get_citation_resolver,
    get_feedback_repo,
    get_openai_client,
    get_plans_repo,
    get_source_tiers,
    get_tavily_client,
)
from app.api.middleware import RequestContext
from app.clients.openai_client import AbstractOpenAIClient
from app.clients.tavily_client import AbstractTavilyClient
from app.config.source_tiers import SourceTiersConfig
from app.prompts.loader import prompt_versions as load_prompt_versions
from app.runtime.orchestrator import Orchestrator
from app.schemas.hypothesis import GeneratePlanRequest
from app.schemas.responses import GeneratePlanResponse
from app.storage.feedback_repo import FeedbackRepo
from app.storage.plans_repo import PlansRepo
from app.verification.catalog_resolver import AbstractCatalogResolver
from app.verification.citation_resolver import AbstractCitationResolver

router = APIRouter()


@router.post("/generate-plan", response_model=GeneratePlanResponse)
async def generate_plan(
    body: GeneratePlanRequest,
    request: Request,
    openai: Annotated[AbstractOpenAIClient, Depends(get_openai_client)],
    tavily: Annotated[AbstractTavilyClient, Depends(get_tavily_client)],
    citation_resolver: Annotated[AbstractCitationResolver, Depends(get_citation_resolver)],
    catalog_resolver: Annotated[AbstractCatalogResolver, Depends(get_catalog_resolver)],
    source_tiers: Annotated[SourceTiersConfig, Depends(get_source_tiers)],
    plans_repo: Annotated[PlansRepo, Depends(get_plans_repo)],
    feedback_repo: Annotated[FeedbackRepo, Depends(get_feedback_repo)],
) -> GeneratePlanResponse:
    ctx: RequestContext = request.state.request_context

    orchestrator = Orchestrator(
        openai=openai,
        tavily=tavily,
        citation_resolver=citation_resolver,
        catalog_resolver=catalog_resolver,
        source_tiers=source_tiers,
        feedback_repo=feedback_repo,
    )
    response = await orchestrator.run(
        hypothesis=body.hypothesis,
        request_id=ctx.request_id,
    )

    summary = response.grounding_summary
    if summary is not None:
        ctx.verified_count += summary.verified_count
        ctx.tier_0_drops += summary.tier_0_drops

    if response.plan_id is not None:
        await plans_repo.save(
            response=response,
            prompt_versions=response.prompt_versions or load_prompt_versions(),
            request_id=ctx.request_id,
        )

    return response
