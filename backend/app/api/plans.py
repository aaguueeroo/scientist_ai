"""`GET /plans/{plan_id}` — read back a previously persisted plan.

A 404 unknown-plan reuses `ErrorCode.VALIDATION_ERROR` (per the user's
pre-resolved decision: the closed `ErrorCode` enum is not extended).
"""

from __future__ import annotations

from typing import Annotated, Any

from fastapi import APIRouter, Depends, Path, Query

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
    "/plans",
    summary="List saved experiment plans",
    description=(
        "Returns up to `limit` persisted plan rows (newest first), with identifiers, "
        "query/hypothesis when present in the stored payload, and `literature_review_id` "
        "when stored. Unlike `GET /conversations`, this includes every plan row, not only "
        "rows that pass the sidebar filter."
    ),
)
async def list_plans(
    plans_repo: Annotated[PlansRepo, Depends(get_plans_repo)],
    limit: Annotated[int, Query(ge=1, le=200, description="Max rows to return.")] = 100,
) -> dict[str, Any]:
    return {"plans": await plans_repo.list_plans(limit=limit)}


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


@router.delete(
    "/plans/{plan_id}",
    status_code=204,
    summary="Delete a saved experiment plan",
    description=(
        "Removes the persisted plan row. Used when the user dismisses a sidebar "
        "recent question. 404 if `plan_id` is unknown (same error envelope as GET)."
    ),
    responses={
        404: {
            "description": "Unknown `plan_id`",
        },
    },
)
async def delete_plan(
    plan_id: Annotated[
        str,
        Path(
            description="Storage key returned with the saved plan.",
            examples=["plan-a1b2c3d-4e5f-6789-0abc-def012345678"],
        ),
    ],
    plans_repo: Annotated[PlansRepo, Depends(get_plans_repo)],
) -> None:
    removed = await plans_repo.delete_by_plan_id(plan_id)
    if not removed:
        raise _PlanNotFound(details={"plan_id": plan_id})
