"""`POST /generate-plan` route.

Step 25 implements the QC-only short-circuit: build runtime Agent 1,
run it, and if the novelty gate says `stop_with_qc`, return a
QC-only `GeneratePlanResponse`. The `continue` branch returns HTTP 501
as a placeholder until Step 33 wires the orchestrator and Agent 3.
"""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request

from app.agents.literature_qc import LiteratureQCAgent
from app.api.deps import (
    get_citation_resolver,
    get_openai_client,
    get_source_tiers,
    get_tavily_client,
)
from app.api.middleware import RequestContext
from app.clients.openai_client import AbstractOpenAIClient
from app.clients.tavily_client import AbstractTavilyClient
from app.config.source_tiers import SourceTiersConfig
from app.prompts.loader import prompt_versions
from app.runtime.novelty_gate import StopWithQC, decide
from app.schemas.hypothesis import GeneratePlanRequest
from app.schemas.responses import GeneratePlanResponse
from app.verification.citation_resolver import AbstractCitationResolver

router = APIRouter()


@router.post("/generate-plan", response_model=GeneratePlanResponse)
async def generate_plan(
    body: GeneratePlanRequest,
    request: Request,
    openai: Annotated[AbstractOpenAIClient, Depends(get_openai_client)],
    tavily: Annotated[AbstractTavilyClient, Depends(get_tavily_client)],
    citation_resolver: Annotated[AbstractCitationResolver, Depends(get_citation_resolver)],
    source_tiers: Annotated[SourceTiersConfig, Depends(get_source_tiers)],
) -> GeneratePlanResponse:
    ctx: RequestContext = request.state.request_context

    agent = LiteratureQCAgent(
        openai=openai,
        tavily=tavily,
        citation_resolver=citation_resolver,
        source_tiers=source_tiers,
    )
    qc = await agent.run(hypothesis=body.hypothesis, request_id=ctx.request_id)
    ctx.verified_count += sum(1 for ref in qc.references if ref.verified)
    ctx.tier_0_drops += qc.tier_0_drops

    outcome = decide(qc.novelty)
    if isinstance(outcome, StopWithQC):
        return GeneratePlanResponse(
            plan_id=None,
            request_id=ctx.request_id,
            qc=qc,
            plan=None,
            grounding_summary=None,
            prompt_versions=prompt_versions(),
        )

    raise HTTPException(
        status_code=501,
        detail="experiment-plan generation is implemented in a later step",
    )
