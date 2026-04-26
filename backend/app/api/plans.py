"""`GET /plans/{plan_id}` — read back a previously persisted plan.

A 404 unknown-plan reuses `ErrorCode.VALIDATION_ERROR` (per the user's
pre-resolved decision: the closed `ErrorCode` enum is not extended).
"""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Path

from app.api.deps import get_plans_repo
from app.api.errors import DomainError
from app.schemas.errors import ErrorCode
from app.schemas.responses import GeneratePlanResponse
from app.storage.plans_repo import PlansRepo


class _PlanNotFound(DomainError):
    code = ErrorCode.VALIDATION_ERROR
    http_status = 404
    default_message = "plan id not found"


router = APIRouter(tags=["Plans"])


@router.get(
    "/plans/{plan_id}",
    response_model=GeneratePlanResponse,
    summary="Load a saved experiment plan",
    description=(
        "Returns the persisted JSON snapshot (GeneratePlanResponse) from a prior "
        "POST /experiment-plan. 404 if plan_id unknown (ErrorResponse, validation_error)."
    ),
    responses={
        404: {
            "description": "Unknown `plan_id`",
        }
    },
)
async def get_plan(
    plan_id: Annotated[
        str,
        Path(
            description="Storage key: plan_id from a successful POST /experiment-plan.",
            examples=["plan-a1b2c3d-4e5f-6789-0abc-def012345678"],
        ),
    ],
    plans_repo: Annotated[PlansRepo, Depends(get_plans_repo)],
) -> GeneratePlanResponse:
    response = await plans_repo.get_by_id(plan_id)
    if response is None:
        raise _PlanNotFound(details={"plan_id": plan_id})
    return response
