"""Async repository for `PlanRow`.

`save(response, prompt_versions, request_id)` stamps `schema_version`,
`prompt_versions`, `request_id`, and `created_at`, then persists the
serialized `GeneratePlanResponse` JSON. `get_by_id(plan_id)` rebuilds
the response from the stored payload (or returns `None` when unknown).
A row whose stored `schema_version` differs from the current
`PLAN_SCHEMA_VERSION` raises `SchemaVersionMismatch` — migration is
deferred to v2.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.schemas.responses import GeneratePlanResponse
from app.storage.models import PLAN_SCHEMA_VERSION, PlanRow


class SchemaVersionMismatch(RuntimeError):
    """Raised when a persisted row's `schema_version` differs from the current."""

    def __init__(self, *, plan_id: str, found: int, expected: int) -> None:
        super().__init__(
            f"plan {plan_id!r} has schema_version={found} but current "
            f"PLAN_SCHEMA_VERSION={expected}; migration deferred to v2"
        )
        self.plan_id = plan_id
        self.found = found
        self.expected = expected


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
        if row.schema_version != PLAN_SCHEMA_VERSION:
            raise SchemaVersionMismatch(
                plan_id=plan_id,
                found=row.schema_version,
                expected=PLAN_SCHEMA_VERSION,
            )
        return GeneratePlanResponse.model_validate(row.payload)
