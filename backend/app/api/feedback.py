"""`POST /feedback` and `GET /feedback` routes.

Legacy few-shot: `POST /feedback` with `plan_id` + `corrected_field` + `before` +
`after` + `reason` (unchanged; Agent 2 retrieval).

Plan review (A1): same path with a mobile `Review` object (`plan_id` +
`original_plan` + `kind` + `payload` + ...). Stored in `review_envelope`;
does not participate in `find_relevant` few-shots. `GET /feedback` returns
`reviews` for plan-review rows only.
"""

from __future__ import annotations

import uuid
from typing import Annotated, Any

from fastapi import APIRouter, Body, Depends, Query, Request
from fastapi.exceptions import RequestValidationError
from pydantic import BaseModel, ConfigDict, Field, ValidationError

from app.agents.feedback_relevance import FeedbackRelevanceAgent
from app.api.deps import get_feedback_repo, get_openai_client
from app.api.middleware import RequestContext
from app.clients.openai_client import AbstractOpenAIClient
from app.prompts.loader import prompt_versions
from app.schemas.feedback import (
    DomainTag,
    FeedbackRecord,
    FeedbackRequest,
    FeedbackResponse,
    PlanReviewEventIn,
    parse_post_feedback_json,
)
from app.storage.feedback_repo import FeedbackRepo

router = APIRouter(tags=["Feedback"])


def _new_feedback_id() -> str:
    return f"fb-{uuid.uuid4().hex}"


class PlanReviewsListResponse(BaseModel):
    """Body for `GET /feedback` (plan reviews only, newest first)."""

    model_config = ConfigDict(extra="forbid")

    reviews: list[dict[str, Any]] = Field(
        default_factory=list,
        description="Stored Review-shaped JSON, `id` set to the server `feedback_id`.",
    )


def _coerce_request_validation(
    err: Exception,
    body: object,
) -> RequestValidationError:
    if isinstance(err, ValidationError):
        return RequestValidationError(err.errors(), body=body)
    if isinstance(err, ValueError):
        return RequestValidationError(
            [
                {
                    "type": "value_error",
                    "loc": ("body",),
                    "msg": str(err),
                    "input": body,
                }
            ],
            body=body,
        )
    raise err


@router.get(
    "/feedback",
    response_model=PlanReviewsListResponse,
    summary="List persisted plan reviews",
    description=(
        "Returns `reviews` (newest first) for rows stored via the plan-review "
        "shape on `POST /feedback`. Legacy few-shot feedback rows are not listed."
    ),
)
async def list_plan_feedback(
    feedback_repo: Annotated[FeedbackRepo, Depends(get_feedback_repo)],
    limit: Annotated[int, Query(ge=1, le=500)] = 200,
) -> PlanReviewsListResponse:
    items = await feedback_repo.list_plan_reviews(limit=limit)
    return PlanReviewsListResponse(reviews=items)


@router.post(
    "/feedback",
    response_model=FeedbackResponse,
    summary="Store feedback: few-shot correction or plan review",
    description=(
        "**Legacy (few-shot):** `plan_id`, `corrected_field`, `before`, `after`, "
        "`reason`; optional `domain_tag` (inferred if omitted). "
        "**Plan review:** full mobile Review with `plan_id`, `original_plan`, "
        "`kind` (`correction` | `comment` | `feedback`), and `payload`."
    ),
)
async def submit_feedback(
    request: Request,
    openai: Annotated[AbstractOpenAIClient, Depends(get_openai_client)],
    feedback_repo: Annotated[FeedbackRepo, Depends(get_feedback_repo)],
    body: object = Body(...),
) -> FeedbackResponse:
    ctx: RequestContext = request.state.request_context

    try:
        parsed = parse_post_feedback_json(body)
    except (ValidationError, ValueError) as e:
        raise _coerce_request_validation(e, body) from e

    if isinstance(parsed, PlanReviewEventIn):
        feedback_id = _new_feedback_id()
        echo: dict[str, Any] = {**parsed.model_dump(mode="json"), "id": feedback_id}
        await feedback_repo.save_plan_review(
            feedback_id=feedback_id,
            plan_id=parsed.plan_id,
            request_id=ctx.request_id,
            prompt_versions=prompt_versions(),
            review_envelope=echo,
        )
        return FeedbackResponse(
            feedback_id=feedback_id,
            request_id=ctx.request_id,
            accepted=True,
            domain_tag=None,
            review=echo,
        )

    p = parsed
    assert isinstance(p, FeedbackRequest)  # narrow

    domain_tag: DomainTag
    if p.domain_tag is not None:
        domain_tag = p.domain_tag
    else:
        agent_2 = FeedbackRelevanceAgent(openai=openai)
        surrogate = (
            f"correction context: {p.reason}\n"
            f"original value: {p.before}\n"
            f"corrected value: {p.after}"
        )
        domain_tag = await agent_2.extract_domain(
            hypothesis=surrogate,
            request_id=ctx.request_id,
        )

    feedback_id = _new_feedback_id()
    record = FeedbackRecord(
        feedback_id=feedback_id,
        plan_id=p.plan_id,
        domain_tag=domain_tag,
        corrected_field=p.corrected_field,
        before=p.before,
        after=p.after,
        reason=p.reason,
    )

    await feedback_repo.save(
        record=record,
        prompt_versions=prompt_versions(),
        request_id=ctx.request_id,
    )

    return FeedbackResponse(
        feedback_id=feedback_id,
        request_id=ctx.request_id,
        accepted=True,
        domain_tag=domain_tag,
        review=None,
    )
