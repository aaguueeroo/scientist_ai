"""SQLAlchemy 2.x declarative ORM rows for the plan + feedback stores.

Schema version constants are a separate, explicit dimension from the
SQLAlchemy column definitions: bumping a column type is a *schema*
migration, while bumping `PLAN_SCHEMA_VERSION` says "the JSON payload
inside `payload` has a new shape, refuse old rows or migrate them in
the read path".
"""

from __future__ import annotations

from datetime import datetime
from typing import Any

from sqlalchemy import JSON, DateTime, Integer, String
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

PLAN_SCHEMA_VERSION = 1
FEEDBACK_SCHEMA_VERSION = 1
LITERATURE_REVIEW_SCHEMA_VERSION = 1


class Base(DeclarativeBase):
    """Declarative base shared by every persisted row."""


class PlanRow(Base):
    """Persisted `GeneratePlanResponse` payload + its provenance metadata."""

    __tablename__ = "plans"

    plan_id: Mapped[str] = mapped_column(String(64), primary_key=True)
    request_id: Mapped[str] = mapped_column(String(64), index=True)
    schema_version: Mapped[int] = mapped_column(Integer, nullable=False)
    prompt_versions: Mapped[dict[str, str]] = mapped_column(JSON, nullable=False)
    domain_tag: Mapped[str | None] = mapped_column(String(64), index=True, nullable=True)
    payload: Mapped[dict[str, Any]] = mapped_column(JSON, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)


class LiteratureReviewRow(Base):
    """Persisted output of `POST /literature-review` (Agent 1) for `POST /experiment-plan`."""

    __tablename__ = "literature_reviews"

    literature_review_id: Mapped[str] = mapped_column(String(80), primary_key=True)
    request_id: Mapped[str] = mapped_column(String(64), index=True)
    query: Mapped[str] = mapped_column(String(4000), nullable=False)
    schema_version: Mapped[int] = mapped_column(Integer, nullable=False)
    payload: Mapped[dict[str, Any]] = mapped_column(JSON, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)


class FeedbackRow(Base):
    """Persisted feedback record + its provenance metadata.

    `before_text` / `after_text` mirror `FeedbackRecord.before` / `.after`
    using non-reserved column names so SQLite cannot collide with its
    keyword set. The repo translates the column names back at read time.
    """

    __tablename__ = "feedback"

    feedback_id: Mapped[str] = mapped_column(String(64), primary_key=True)
    plan_id: Mapped[str] = mapped_column(String(64), index=True)
    request_id: Mapped[str] = mapped_column(String(64), index=True)
    schema_version: Mapped[int] = mapped_column(Integer, nullable=False)
    prompt_versions: Mapped[dict[str, str]] = mapped_column(JSON, nullable=False)
    domain_tag: Mapped[str] = mapped_column(String(64), index=True)
    corrected_field: Mapped[str] = mapped_column(String(120))
    before_text: Mapped[str] = mapped_column(String(4000))
    after_text: Mapped[str] = mapped_column(String(4000))
    reason: Mapped[str] = mapped_column(String(2000))
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
