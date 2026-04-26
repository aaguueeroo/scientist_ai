"""Async repository for `PlanRow`.

`save(response, prompt_versions, request_id)` stamps `schema_version`,
`prompt_versions`, `request_id`, and `created_at`, then persists the
serialized `GeneratePlanResponse` JSON. `get_by_id(plan_id)` rebuilds
the response from the stored payload (or returns `None` when unknown).
A row whose stored `schema_version` is not in `_READABLE_PLAN_SCHEMA_VERSIONS`
raises `SchemaVersionMismatch` (new saves stamp `PLAN_SCHEMA_VERSION`).
"""

from __future__ import annotations

import secrets
import string
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.schemas.responses import GeneratePlanResponse
from app.storage.models import PLAN_SCHEMA_VERSION, PlanRow

# Read path accepts any stamp we still deserialize with `GeneratePlanResponse`
# (v1 and v2 share the same Pydantic shape today; only the column value differs).
_READABLE_PLAN_SCHEMA_VERSIONS: frozenset[int] = frozenset({1, 2})

# Storage primary key: alphanumeric only (no chat titles / human-readable slugs).
_PLAN_ID_CHARS = string.ascii_letters + string.digits
_PLAN_ID_LEN = 24
_MAX_PLAN_ID_ALLOC_ATTEMPTS = 64


class SchemaVersionMismatch(RuntimeError):
    """Raised when a persisted row's `schema_version` differs from the current."""

    def __init__(self, *, plan_id: str, found: int, expected: int) -> None:
        super().__init__(
            f"plan {plan_id!r} has schema_version={found} but this build only "
            f"reads versions {sorted(_READABLE_PLAN_SCHEMA_VERSIONS)} "
            f"(new saves use PLAN_SCHEMA_VERSION={expected})"
        )
        self.plan_id = plan_id
        self.found = found
        self.expected = expected


@dataclass
class PlansRepo:
    """Read/write `PlanRow` rows."""

    session_factory: async_sessionmaker[AsyncSession]

    async def allocate_unique_plan_id(self) -> str:
        """Return a new primary-key string not yet present in ``plans``."""
        for _ in range(_MAX_PLAN_ID_ALLOC_ATTEMPTS):
            candidate = "".join(
                secrets.choice(_PLAN_ID_CHARS) for _ in range(_PLAN_ID_LEN)
            )
            if await self.get_row_by_id(candidate) is None:
                return candidate
        raise RuntimeError(
            f"exhausted {_MAX_PLAN_ID_ALLOC_ATTEMPTS} attempts allocating a unique plan_id"
        )

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

    async def delete_by_plan_id(self, plan_id: str) -> bool:
        """Delete a plan row by primary key. Returns whether a row was removed."""
        tid = plan_id.strip()
        if not tid:
            return False
        async with self.session_factory() as session, session.begin():
            result = await session.execute(delete(PlanRow).where(PlanRow.plan_id == tid))
            return (result.rowcount or 0) > 0

    async def get_by_id(self, plan_id: str) -> GeneratePlanResponse | None:
        row = await self.get_row_by_id(plan_id)
        if row is None:
            return None
        if row.schema_version not in _READABLE_PLAN_SCHEMA_VERSIONS:
            raise SchemaVersionMismatch(
                plan_id=plan_id,
                found=row.schema_version,
                expected=PLAN_SCHEMA_VERSION,
            )
        return GeneratePlanResponse.model_validate(row.payload)

    async def list_conversation_summaries(self, limit: int) -> list[dict[str, Any]]:
        """Rows with a persisted plan + hypothesis, newest first (sidebar restore).

        `literature_review_id` is present when the stored payload includes it; older
        rows may omit it and return an empty string.
        """
        if limit < 1:
            return []
        async with self.session_factory() as session:
            result = await session.execute(
                select(PlanRow).order_by(PlanRow.created_at.desc()).limit(max(limit * 2, limit))
            )
            rows = result.scalars().all()
        out: list[dict[str, Any]] = []
        for row in rows:
            if len(out) >= limit:
                break
            p = row.payload
            if not isinstance(p, dict):
                continue
            plan = p.get("plan")
            if not isinstance(plan, dict):
                continue
            hypothesis = plan.get("hypothesis")
            if not isinstance(hypothesis, str) or not hypothesis.strip():
                continue
            plan_id = p.get("plan_id")
            if not isinstance(plan_id, str) or not plan_id.strip():
                continue
            raw_lit = p.get("literature_review_id", "")
            lit = raw_lit if isinstance(raw_lit, str) else ""
            out.append(
                {
                    "query": hypothesis.strip(),
                    "plan_id": plan_id,
                    "literature_review_id": lit,
                }
            )
        return out

    async def list_plans(self, limit: int) -> list[dict[str, Any]]:
        """All persisted plan rows, newest first. Includes rows without a hypothesis in the payload.

        Each item: ``plan_id``, ``request_id``, ``schema_version``, ``query`` (hypothesis
        or empty string), ``literature_review_id`` (if stored on the payload), ``created_at``
        (ISO-8601 string, UTC).
        """
        if limit < 1:
            return []
        async with self.session_factory() as session:
            result = await session.execute(
                select(PlanRow).order_by(PlanRow.created_at.desc()).limit(limit)
            )
            rows = result.scalars().all()
        out: list[dict[str, Any]] = []
        for row in rows:
            p = row.payload
            if not isinstance(p, dict):
                p = {}
            plan = p.get("plan")
            query = ""
            if isinstance(plan, dict):
                h = plan.get("hypothesis")
                if isinstance(h, str) and h.strip():
                    query = h.strip()
            plan_id = p.get("plan_id")
            if not isinstance(plan_id, str) or not plan_id.strip():
                plan_id = row.plan_id
            raw_lit = p.get("literature_review_id", "")
            lit = raw_lit if isinstance(raw_lit, str) else ""
            created = row.created_at
            if created.tzinfo is None:
                created_s = f"{created.isoformat()}Z"
            else:
                created_s = created.astimezone(UTC).isoformat()
            out.append(
                {
                    "plan_id": plan_id,
                    "request_id": row.request_id,
                    "schema_version": row.schema_version,
                    "query": query,
                    "literature_review_id": lit,
                    "created_at": created_s,
                }
            )
        return out
