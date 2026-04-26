"""`POST /feedback` route.

Persists a `FeedbackRow` via `FeedbackRepo.save(...)` and returns a
typed `FeedbackResponse`. If `domain_tag` is omitted, runtime Agent 2's
domain-extraction step derives it from the correction text. The route
always stamps `prompt_versions`, `schema_version`, and `request_id` onto
the persisted row.
"""

from __future__ import annotations

import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Request

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
)
from app.storage.feedback_repo import FeedbackRepo

router = APIRouter(tags=["Feedback"])


def _new_feedback_id() -> str:
    return f"fb-{uuid.uuid4().hex}"


@router.post(
    "/feedback",
    response_model=FeedbackResponse,
    summary="Store a scientist correction",
    description=(
        "Saves a correction for plan_id; domain_tag can be omitted (inferred). "
        "Agent 2 may use it as few-shots on later POST /experiment-plan. "
        "Returns feedback_id and request_id."
    ),
)
async def submit_feedback(
    body: FeedbackRequest,
    request: Request,
    openai: Annotated[AbstractOpenAIClient, Depends(get_openai_client)],
    feedback_repo: Annotated[FeedbackRepo, Depends(get_feedback_repo)],
) -> FeedbackResponse:
    ctx: RequestContext = request.state.request_context

    domain_tag: DomainTag
    if body.domain_tag is not None:
        domain_tag = body.domain_tag
    else:
        agent_2 = FeedbackRelevanceAgent(openai=openai)
        surrogate = (
            f"correction context: {body.reason}\n"
            f"original value: {body.before}\n"
            f"corrected value: {body.after}"
        )
        domain_tag = await agent_2.extract_domain(
            hypothesis=surrogate,
            request_id=ctx.request_id,
        )

    feedback_id = _new_feedback_id()
    record = FeedbackRecord(
        feedback_id=feedback_id,
        plan_id=body.plan_id,
        domain_tag=domain_tag,
        corrected_field=body.corrected_field,
        before=body.before,
        after=body.after,
        reason=body.reason,
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
    )
