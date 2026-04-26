"""`POST /experiment-plan` — runs the pipeline using a stored literature review (Agent 1 result)."""

from __future__ import annotations

import time
from typing import Annotated

import structlog
from fastapi import APIRouter, Depends, Request

from app.api.deps import (
    get_catalog_resolver,
    get_citation_resolver,
    get_feedback_repo,
    get_literature_review_repo,
    get_openai_client,
    get_plans_repo,
    get_source_tiers,
    get_tavily_client,
)
from app.api.errors import DomainError
from app.api.middleware import RequestContext
from app.clients.openai_client import AbstractOpenAIClient
from app.clients.tavily_client import AbstractTavilyClient
from app.config.settings import get_settings
from app.config.source_tiers import SourceTiersConfig
from app.observability.timing import truncate_preview
from app.prompts.loader import prompt_versions as load_prompt_versions
from app.runtime.orchestrator import Orchestrator
from app.schemas.errors import ErrorCode, ErrorResponse
from app.schemas.pipeline_http import ExperimentPlanHttpRequest
from app.schemas.responses import GeneratePlanResponse
from app.storage.feedback_repo import FeedbackRepo
from app.storage.literature_review_repo import LiteratureReviewRepo
from app.storage.plans_repo import PlansRepo
from app.verification.catalog_resolver import AbstractCatalogResolver
from app.verification.citation_resolver import AbstractCitationResolver

router = APIRouter(tags=["Experiment plan"])
_log = structlog.get_logger("app")


class _LiteratureReviewNotFound(DomainError):
    code = ErrorCode.VALIDATION_ERROR
    http_status = 422
    default_message = "literature_review_id not found"


class _LiteratureQueryMismatch(DomainError):
    code = ErrorCode.VALIDATION_ERROR
    http_status = 422
    default_message = "query does not match stored literature review"


@router.post(
    "/experiment-plan",
    response_model=GeneratePlanResponse,
    summary="Generate or short-circuit experiment plan (Agents 2-3)",
    description=(
        "Requires `literature_review_id` from `POST /literature-review` and the same "
        "`query` (after trim). Loads cached Agent-1 **LiteratureQCResult** (see OpenAPI "
        "`components.schemas.LiteratureQCResult` and `LiteratureQcReference`), then novelty "
        "gate, optional feedback few-shots, experiment planner, and citation/catalog "
        "grounding. On success, saves the plan row. See the **example** on GeneratePlanResponse."
    ),
    responses={
        200: {
            "description": (
                "GeneratePlanResponse: qc, optional plan, grounding_summary, prompt_versions. "
                "If no citation or catalog slot verified, `grounding_summary.grounding_caveat` "
                "is set and the plan still returns 200 (rows remain unverified)."
            ),
        },
        422: {
            "model": ErrorResponse,
            "description": (
                "Validation, unknown literature_review_id, query mismatch, "
                "or other domain errors. Check code in body."
            ),
        },
    },
)
async def post_experiment_plan(
    body: ExperimentPlanHttpRequest,
    request: Request,
    openai: Annotated[AbstractOpenAIClient, Depends(get_openai_client)],
    tavily: Annotated[AbstractTavilyClient, Depends(get_tavily_client)],
    citation_resolver: Annotated[AbstractCitationResolver, Depends(get_citation_resolver)],
    catalog_resolver: Annotated[AbstractCatalogResolver, Depends(get_catalog_resolver)],
    source_tiers: Annotated[SourceTiersConfig, Depends(get_source_tiers)],
    plans_repo: Annotated[PlansRepo, Depends(get_plans_repo)],
    feedback_repo: Annotated[FeedbackRepo, Depends(get_feedback_repo)],
    literature_repo: Annotated[LiteratureReviewRepo, Depends(get_literature_review_repo)],
) -> GeneratePlanResponse:
    ctx: RequestContext = request.state.request_context

    row = await literature_repo.get_by_id(body.literature_review_id)
    if row is None:
        raise _LiteratureReviewNotFound(
            message=f"unknown literature_review_id: {body.literature_review_id!r}",
            details={"literature_review_id": body.literature_review_id},
        )
    stored_query, precached = row
    if stored_query.strip() != body.query.strip():
        raise _LiteratureQueryMismatch(
            details={"literature_review_id": body.literature_review_id},
        )

    max_prev = get_settings().LOG_DEBUG_PREVIEW_CHARS
    _log.debug(
        "app.experiment_plan.input",
        request_id=ctx.request_id,
        query_preview=truncate_preview(body.query, max_prev),
        query_len=len(body.query),
        literature_review_id=body.literature_review_id,
        precached_literature_qc=True,
    )

    orchestrator = Orchestrator(
        openai=openai,
        tavily=tavily,
        citation_resolver=citation_resolver,
        catalog_resolver=catalog_resolver,
        source_tiers=source_tiers,
        feedback_repo=feedback_repo,
    )
    t0 = time.perf_counter()
    response = await orchestrator.run(
        hypothesis=body.query,
        request_id=ctx.request_id,
        precached_literature_qc=precached,
    )
    if response.plan is not None:
        server_plan_id = await plans_repo.allocate_unique_plan_id()
        response = response.model_copy(
            update={
                "plan_id": server_plan_id,
                "plan": response.plan.model_copy(update={"plan_id": server_plan_id}),
            }
        )
    _log.debug(
        "app.experiment_plan.output",
        request_id=ctx.request_id,
        pipeline_elapsed_ms=int((time.perf_counter() - t0) * 1000),
        plan_id=response.plan_id,
        has_plan=response.plan is not None,
        novelty=response.qc.novelty.value,
        qc_reference_count=len(response.qc.references),
        has_similarity_suggestion=response.qc.similarity_suggestion is not None,
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
