"""Tests for `GET /plans/{plan_id}` and the persist-on-generate path (Step 37)."""

# Pydantic v2 coerces plain string URLs into `HttpUrl` at validation time,
# but the pydantic mypy plugin synthesises strict `__init__` signatures that
# reject `str`. Test fixtures here pass literal URLs as `str`; this
# file-level directive silences the resulting `[arg-type]` false positives.
# mypy: disable-error-code="arg-type"

from __future__ import annotations

from collections.abc import AsyncIterator

import pytest
import pytest_asyncio
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import create_async_engine

from app.api import deps as api_deps
from app.clients.openai_client import FakeOpenAIClient
from app.clients.tavily_client import FakeTavilyClient
from app.schemas.errors import ErrorCode
from app.schemas.experiment_plan import Material
from app.schemas.literature_qc import SourceTier
from app.storage import db as storage_db
from app.storage.models import PLAN_SCHEMA_VERSION
from app.verification.catalog_resolver import FakeCatalogResolver
from app.verification.citation_resolver import FakeCitationResolver
from tests.api.test_experiment_plan import (
    NATURE_URL,
    SAMPLE_HYPOTHESIS,
    _full_path_clients,
    _verified_nature_outcome,
    post_literature_then_experiment_plan,
)


def _build_full_path_clients() -> tuple[
    FakeOpenAIClient,
    FakeTavilyClient,
    FakeCitationResolver,
    FakeCatalogResolver,
]:
    citation_resolver = FakeCitationResolver(outcomes={NATURE_URL: _verified_nature_outcome()})
    trehalose_verified = Material(
        reagent="Trehalose dihydrate",
        vendor="Sigma-Aldrich",
        sku="T9531",
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    ).model_copy(
        update={
            "verified": True,
            "verification_url": "https://www.sigmaaldrich.com/US/en/product/sigma/T9531",
            "confidence": "high",
        }
    )
    dmem_verified = Material(
        reagent="DMEM cell-culture medium",
        vendor="Thermo Fisher",
        sku="11965092",
        tier=SourceTier.TIER_1_PEER_REVIEWED,
    ).model_copy(
        update={
            "verified": True,
            "verification_url": "https://www.thermofisher.com/order/catalog/product/11965092",
            "confidence": "high",
        }
    )
    catalog_resolver = FakeCatalogResolver(
        outcomes={"T9531": trehalose_verified, "11965092": dmem_verified},
    )
    return _full_path_clients(
        citation_resolver=citation_resolver,
        catalog_resolver=catalog_resolver,
    )


@pytest_asyncio.fixture
async def persisted_app(monkeypatch: pytest.MonkeyPatch) -> AsyncIterator[FastAPI]:
    """Build an app with full-orchestrator wiring + an in-memory SQLite store."""

    from app.main import create_app

    openai, tavily, citation_resolver, catalog_resolver = _build_full_path_clients()

    monkeypatch.setattr(api_deps, "build_openai_client", lambda settings: openai)
    monkeypatch.setattr(
        api_deps,
        "build_tavily_client",
        lambda settings, source_tiers: tavily,
    )
    monkeypatch.setattr(
        api_deps,
        "build_citation_resolver",
        lambda source_tiers: citation_resolver,
    )
    monkeypatch.setattr(
        api_deps,
        "build_catalog_resolver",
        lambda source_tiers: catalog_resolver,
    )
    monkeypatch.setattr(
        storage_db,
        "create_engine",
        lambda settings: create_async_engine("sqlite+aiosqlite:///:memory:", future=True),
    )

    app = create_app()
    async with app.router.lifespan_context(app):
        yield app


@pytest.mark.asyncio
async def test_experiment_plan_persists_row_with_prompt_versions_and_schema_version(
    persisted_app: FastAPI,
) -> None:
    transport = ASGITransport(app=persisted_app, raise_app_exceptions=False)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        body = await post_literature_then_experiment_plan(client, query=SAMPLE_HYPOTHESIS)
    plan_id = body["plan_id"]
    assert plan_id

    repo = persisted_app.state.plans_repo
    row = await repo.get_row_by_id(plan_id)
    assert row is not None
    assert row.schema_version == PLAN_SCHEMA_VERSION
    assert row.prompt_versions == body["prompt_versions"]
    assert row.request_id == body["request_id"]


@pytest.mark.asyncio
async def test_get_plans_id_returns_persisted_response(persisted_app: FastAPI) -> None:
    transport = ASGITransport(app=persisted_app, raise_app_exceptions=False)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        post_body = await post_literature_then_experiment_plan(client, query=SAMPLE_HYPOTHESIS)
        plan_id = post_body["plan_id"]

        get = await client.get(f"/plans/{plan_id}")

    assert get.status_code == 200
    body = get.json()
    assert body["plan_id"] == plan_id
    assert body["plan"]["plan_id"] == plan_id


@pytest.mark.asyncio
async def test_get_plans_id_unknown_returns_404_with_error_response(
    persisted_app: FastAPI,
) -> None:
    transport = ASGITransport(app=persisted_app, raise_app_exceptions=False)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/plans/plan-does-not-exist")

    assert response.status_code == 404
    body = response.json()
    assert body["code"] == ErrorCode.VALIDATION_ERROR.value
    assert body["request_id"]
