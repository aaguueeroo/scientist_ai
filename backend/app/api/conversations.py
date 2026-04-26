"""`GET /conversations` — recent saved sessions for the Flutter sidebar."""

from __future__ import annotations

from typing import Annotated, Any

from fastapi import APIRouter, Depends, Query

from app.api.deps import get_plans_repo
from app.storage.plans_repo import PlansRepo

router = APIRouter(tags=["Conversations"])


@router.get(
    "/conversations",
    summary="List recent saved experiment sessions",
    description=(
        "Returns up to `limit` rows from persisted plans (newest first), each with "
        "the client research `query`, `literature_review_id`, and `plan_id` so the "
        "UI can repopulate the sidebar and restore without re-running agents. "
        "Rows saved before provenance metadata was added are omitted."
    ),
)
async def list_conversations(
    plans_repo: Annotated[PlansRepo, Depends(get_plans_repo)],
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
) -> dict[str, Any]:
    items = await plans_repo.list_conversation_summaries(limit=limit)
    return {"conversations": items}
