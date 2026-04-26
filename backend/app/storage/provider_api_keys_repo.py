"""Load and persist OpenAI / Tavily API keys (singleton row id=1)."""

from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.storage.models import ProviderApiKeysRow

_SINGLETON_ID = 1


class ProviderApiKeysRepo:
    def __init__(self, session_factory: async_sessionmaker[AsyncSession]) -> None:
        self._session_factory = session_factory

    async def get_keys(self) -> tuple[str | None, str | None]:
        """Return stored (openai_key, tavily_key), each optional."""

        async with self._session_factory() as session:
            row = await session.get(ProviderApiKeysRow, _SINGLETON_ID)
            if row is None:
                return None, None
            o = (row.openai_key or "").strip() or None
            t = (row.tavily_key or "").strip() or None
            return o, t

    async def upsert_keys(
        self,
        *,
        openai_key: str | None = None,
        tavily_key: str | None = None,
    ) -> None:
        """Set provided keys; None means leave existing value unchanged."""

        async with self._session_factory() as session:
            async with session.begin():
                row = await session.get(ProviderApiKeysRow, _SINGLETON_ID)
                now = datetime.now(UTC).replace(tzinfo=None)
                if row is None:
                    o_val: str | None = None
                    t_val: str | None = None
                    if openai_key is not None:
                        s = openai_key.strip()
                        o_val = s if s else None
                    if tavily_key is not None:
                        s = tavily_key.strip()
                        t_val = s if s else None
                    session.add(
                        ProviderApiKeysRow(
                            id=_SINGLETON_ID,
                            openai_key=o_val,
                            tavily_key=t_val,
                            updated_at=now,
                        )
                    )
                else:
                    if openai_key is not None:
                        s = openai_key.strip()
                        row.openai_key = s if s else None
                    if tavily_key is not None:
                        s = tavily_key.strip()
                        row.tavily_key = s if s else None
                    row.updated_at = now

    async def clear_all(self) -> None:
        async with self._session_factory() as session:
            async with session.begin():
                row = await session.get(ProviderApiKeysRow, _SINGLETON_ID)
                if row is not None:
                    row.openai_key = None
                    row.tavily_key = None
                    row.updated_at = datetime.now(UTC).replace(tzinfo=None)
