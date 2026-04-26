from __future__ import annotations

import pytest
from httpx import ASGITransport, AsyncClient

from app.config.settings import get_settings
from app.main import create_app


@pytest.mark.asyncio
async def test_get_put_provider_api_keys(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("OPENAI_API_KEY", "")
    monkeypatch.setenv("TAVILY_API_KEY", "")
    monkeypatch.setenv("DATABASE_URL", "sqlite+aiosqlite:///:memory:")
    get_settings.cache_clear()
    test_app = create_app()
    async with test_app.router.lifespan_context(test_app):
        transport = ASGITransport(app=test_app)
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            r0 = await ac.get("/settings/provider-api-keys")
            assert r0.status_code == 200
            data0 = r0.json()
            assert data0["openai_configured"] is False
            assert data0["tavily_configured"] is False

            r1 = await ac.put(
                "/settings/provider-api-keys",
                json={"openai_api_key": "sk-test", "tavily_api_key": "tvly-test"},
            )
            assert r1.status_code == 200
            data1 = r1.json()
            assert data1["openai_configured"] is True
            assert data1["tavily_configured"] is True

            r2 = await ac.get("/settings/provider-api-keys")
            assert r2.json() == data1
