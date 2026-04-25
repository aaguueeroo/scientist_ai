"""Async repository for `FeedbackRow`.

`save(record, prompt_versions, request_id)` stamps `schema_version`,
`prompt_versions`, `request_id`, and `created_at`, then persists the
record. `find_relevant(domain_tag, k=5)` returns the `k` most-recent
records whose `domain_tag` matches, reformulated as `FewShotExample`
instances with a recency-boosted relevance score in `[0.0, 1.0]`.

The `relevance_score` is computed from row position only (most-recent
row gets the highest score, oldest gets the lowest); semantic re-ranking
of the corrected text against a hypothesis is the job of runtime
Agent 2 (`app/agents/feedback_relevance.py`, Step 41), not this repo.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.schemas.feedback import DomainTag, FeedbackRecord, FewShotExample
from app.storage.models import FEEDBACK_SCHEMA_VERSION, FeedbackRow


@dataclass
class FeedbackRepo:
    """Read/write `FeedbackRow` rows."""

    session_factory: async_sessionmaker[AsyncSession]

    async def save(
        self,
        *,
        record: FeedbackRecord,
        prompt_versions: dict[str, str],
        request_id: str,
    ) -> FeedbackRow:
        row = FeedbackRow(
            feedback_id=record.feedback_id,
            plan_id=record.plan_id,
            request_id=request_id,
            schema_version=FEEDBACK_SCHEMA_VERSION,
            prompt_versions=dict(prompt_versions),
            domain_tag=record.domain_tag.value,
            corrected_field=record.corrected_field,
            before_text=record.before,
            after_text=record.after,
            reason=record.reason,
            created_at=datetime.now(UTC).replace(tzinfo=None),
        )

        async with self.session_factory() as session, session.begin():
            session.add(row)
        return row

    async def count(self) -> int:
        """Total number of `FeedbackRow`s persisted (across all domains).

        Used by Agent 2's short-circuit: when the store is empty there is
        no point spending a domain-extraction LLM call only to retrieve
        zero candidates.
        """

        async with self.session_factory() as session:
            result = await session.execute(select(func.count(FeedbackRow.feedback_id)))
            total = result.scalar_one()
            return int(total)

    async def get_row_by_id(self, feedback_id: str) -> FeedbackRow | None:
        async with self.session_factory() as session:
            result = await session.execute(
                select(FeedbackRow).where(FeedbackRow.feedback_id == feedback_id)
            )
            return result.scalar_one_or_none()

    async def find_relevant(
        self,
        *,
        domain_tag: DomainTag,
        k: int = 5,
    ) -> list[FewShotExample]:
        if k <= 0:
            return []

        async with self.session_factory() as session:
            result = await session.execute(
                select(FeedbackRow)
                .where(FeedbackRow.domain_tag == domain_tag.value)
                .order_by(FeedbackRow.created_at.desc())
                .limit(k)
            )
            rows = list(result.scalars().all())

        if not rows:
            return []

        examples: list[FewShotExample] = []
        for index, row in enumerate(rows):
            recency_score = 1.0 - (index / max(1, len(rows)))
            examples.append(
                FewShotExample(
                    corrected_field=row.corrected_field,
                    before=row.before_text,
                    after=row.after_text,
                    reason=row.reason,
                    domain_tag=DomainTag(row.domain_tag),
                    relevance_score=round(recency_score, 4),
                )
            )
        return examples
