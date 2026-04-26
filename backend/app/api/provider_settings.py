"""Persist and inspect user API keys (stored in DB; used when env/headers absent)."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel, Field

from app.storage.provider_api_keys_repo import ProviderApiKeysRepo

router = APIRouter(tags=["Settings"])


class ProviderApiKeysStatus(BaseModel):
    openai_configured: bool = Field(description="True when a non-empty OpenAI key is stored.")
    tavily_configured: bool = Field(description="True when a non-empty Tavily key is stored.")


class ProviderApiKeysPutBody(BaseModel):
    openai_api_key: str | None = Field(
        default=None,
        description="If set (including empty string), updates the stored OpenAI key.",
    )
    tavily_api_key: str | None = Field(
        default=None,
        description="If set (including empty string), updates the stored Tavily key.",
    )


def _repo(request: Request) -> ProviderApiKeysRepo:
    return ProviderApiKeysRepo(request.app.state.db_session_factory)


@router.get(
    "/settings/provider-api-keys",
    response_model=ProviderApiKeysStatus,
    summary="Whether OpenAI/Tavily keys are stored server-side",
)
async def get_provider_api_keys_status(
    request: Request,
    repo: Annotated[ProviderApiKeysRepo, Depends(_repo)],
) -> ProviderApiKeysStatus:
    o, t = await repo.get_keys()
    return ProviderApiKeysStatus(
        openai_configured=bool(o),
        tavily_configured=bool(t),
    )


@router.put(
    "/settings/provider-api-keys",
    response_model=ProviderApiKeysStatus,
    summary="Store or update OpenAI and/or Tavily API keys",
    description=(
        "Saves keys in the application database. Omit a field to leave the existing "
        "value unchanged. Pass an empty string to clear a stored key."
    ),
)
async def put_provider_api_keys(
    body: ProviderApiKeysPutBody,
    request: Request,
    repo: Annotated[ProviderApiKeysRepo, Depends(_repo)],
) -> ProviderApiKeysStatus:
    await repo.upsert_keys(
        openai_key=body.openai_api_key,
        tavily_key=body.tavily_api_key,
    )
    o, t = await repo.get_keys()
    return ProviderApiKeysStatus(
        openai_configured=bool(o),
        tavily_configured=bool(t),
    )
