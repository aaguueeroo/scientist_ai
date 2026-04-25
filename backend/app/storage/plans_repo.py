"""Async repository for `PlanRow`.

`save(response, prompt_versions, request_id)` stamps `schema_version`,
`prompt_versions`, `request_id`, and `created_at`, then persists the
serialized `GeneratePlanResponse` JSON. `get_by_id(plan_id)` rebuilds
the response from the stored payload (or returns `None` when unknown).
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.schemas.responses import GeneratePlanResponse
from app.storage.models import PLAN_SCHEMA_VERSION, PlanRow


@dataclass
class PlansRepo:
    """Read/write `PlanRow` rows."""

    session_factory: async_sessionmaker[AsyncSession]

    async def save(
        self,
        *,
        response: GeneratePlanResponse,
        prompt_versions: dict[str, str],
        request_id: str,
    ) -> PlanRow:
        if response.plan_id is None:
            raise ValueError("plans_repo.save requires response.plan_id to be set")

        payload: dict[str, Any] = response.model_dump(mode="json")
        row = PlanRow(
            plan_id=response.plan_id,
            request_id=request_id,
            schema_version=PLAN_SCHEMA_VERSION,
            prompt_versions=dict(prompt_versions),
            domain_tag=None,
            payload=payload,
            created_at=datetime.now(UTC).replace(tzinfo=None),
        )

        async with self.session_factory() as session, session.begin():
            session.add(row)
        return row

    async def get_row_by_id(self, plan_id: str) -> PlanRow | None:
        async with self.session_factory() as session:
            result = await session.execute(select(PlanRow).where(PlanRow.plan_id == plan_id))
            return result.scalar_one_or_none()

    async def get_by_id(self, plan_id: str) -> GeneratePlanResponse | None:
        row = await self.get_row_by_id(plan_id)
        if row is None:
            return None
        return GeneratePlanResponse.model_validate(row.payload)
