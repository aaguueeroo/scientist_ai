"""Persistence for `LiteratureReviewRow` (Agent 1 result keyed by `literature_review_id`)."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.schemas.literature_qc import LiteratureQCResult
from app.storage.models import LITERATURE_REVIEW_SCHEMA_VERSION, LiteratureReviewRow


@dataclass
class LiteratureReviewRepo:
    """Read/write `literature_reviews` rows."""

    session_factory: async_sessionmaker[AsyncSession]

    async def save(
        self,
        *,
        literature_review_id: str,
        request_id: str,
        query: str,
        qc: LiteratureQCResult,
    ) -> None:
        payload: dict[str, Any] = qc.model_dump(mode="json")
        row = LiteratureReviewRow(
            literature_review_id=literature_review_id,
            request_id=request_id,
            query=query,
            schema_version=LITERATURE_REVIEW_SCHEMA_VERSION,
            payload=payload,
            created_at=datetime.now(UTC).replace(tzinfo=None),
        )
        async with self.session_factory() as session, session.begin():
            session.add(row)

    async def get_by_id(self, literature_review_id: str) -> tuple[str, LiteratureQCResult] | None:
        async with self.session_factory() as session:
            result = await session.execute(
                select(LiteratureReviewRow).where(
                    LiteratureReviewRow.literature_review_id == literature_review_id
                )
            )
            row = result.scalar_one_or_none()
        if row is None:
            return None
        if row.schema_version != LITERATURE_REVIEW_SCHEMA_VERSION:
            return None
        qc = LiteratureQCResult.model_validate(row.payload)
        return (row.query, qc)

    async def list_literature_reviews(self, limit: int) -> list[dict[str, Any]]:
        """All stored literature review rows (current schema only), newest first.

        Each item: ``literature_review_id``, ``request_id``, ``query``, ``created_at`` (ISO-8601, UTC).
        """
        if limit < 1:
            return []
        async with self.session_factory() as session:
            result = await session.execute(
                select(LiteratureReviewRow)
                .where(LiteratureReviewRow.schema_version == LITERATURE_REVIEW_SCHEMA_VERSION)
                .order_by(LiteratureReviewRow.created_at.desc())
                .limit(limit)
            )
            rows = result.scalars().all()
        out: list[dict[str, Any]] = []
        for row in rows:
            created = row.created_at
            if created.tzinfo is None:
                created_s = f"{created.isoformat()}Z"
            else:
                created_s = created.astimezone(UTC).isoformat()
            out.append(
                {
                    "literature_review_id": row.literature_review_id,
                    "request_id": row.request_id,
                    "query": row.query,
                    "created_at": created_s,
                }
            )
        return out
