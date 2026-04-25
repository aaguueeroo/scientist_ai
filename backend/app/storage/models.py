"""SQLAlchemy 2.x declarative base.

Step 35 only exposes the `Base` class so `db.create_all` has metadata to
create. The concrete `PlanRow` (Step 36) and `FeedbackRow` (Step 40)
declarations land here in their own steps.
"""

from __future__ import annotations

from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    """Declarative base shared by every persisted row."""
