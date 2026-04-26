"""`GET /debug/tavily` — minimal Tavily probe (uses `TAVILY_API_KEY` via the app client)."""

from __future__ import annotations

from typing import Annotated, Any, Literal

from fastapi import APIRouter, Depends, Query

from app.api.deps import get_source_tiers, get_tavily_client
from app.api.provider_key_context import install_provider_keys
from app.clients.tavily_client import AbstractTavilyClient, TavilyResearchModel
from app.config.settings import Settings, get_settings
from app.config.source_tiers import SourceTiersConfig

router = APIRouter(tags=["Debug"])


@router.get(
    "/debug/tavily",
    dependencies=[Depends(install_provider_keys)],
    summary="Raw Tavily Search or Research call",
    description=(
        "Debug/operator only. Returns upstream Tavily JSON (search or research) only — "
        "no 'unverified similar' row is added here. By default, Search uses the same "
        "`include_domains` allowlist as Agent 1; long or niche queries can return an empty "
        "`results` list. Set `restrict_domains=false` to omit the allowlist (closer to the "
        "public Tavily UI). The literature pipeline may still perform an **internal** open-web "
        "Tavily call when the allowlist yields nothing, which this endpoint does not mirror. "
        "Costs money and quota."
    ),
    responses={
        200: {
            "description": "Tavily API JSON (shape depends on `mode`).",
            "content": {
                "application/json": {
                    "example": {
                        "query": "trehalose cryopreservation HeLa",
                        "results": [
                            {
                                "title": "Trehalose as a cryoprotectant",
                                "url": "https://example.com/article/1",
                                "content": "Abstract snippet…",
                                "score": 0.91,
                            }
                        ],
                    }
                }
            },
        }
    },
)
async def debug_tavily(
    tavily: Annotated[AbstractTavilyClient, Depends(get_tavily_client)],
    source_tiers: Annotated[SourceTiersConfig, Depends(get_source_tiers)],
    settings: Annotated[Settings, Depends(get_settings)],
    q: Annotated[
        str,
        Query(
            min_length=1,
            max_length=2000,
            description="Search string (Search) or research task `input` (Research).",
        ),
    ],
    mode: Literal["search", "research"] = Query(
        "search",
        description=(
            "`search` = raw Tavily Search (`/search`). "
            "`research` = Research task to completion (`/research`)."
        ),
    ),
    depth: Literal["basic", "advanced"] = "basic",
    max_results: Annotated[int, Query(ge=1, le=20)] = 5,
    tavily_research_model: Annotated[
        TavilyResearchModel | None,
        Query(
            description=("When mode=research: mini|pro|auto (default: env TAVILY_RESEARCH_MODEL)."),
        ),
    ] = None,
    restrict_domains: bool = Query(
        True,
        description=(
            "When mode=search: if true, pass Agent 1's Tier1+2 `include_domains` to Tavily. "
            "If false, omit include_domains (web-wide serp; often matches tavily.com play UI "
            "better than a strict allowlist)."
        ),
    ),
) -> dict[str, Any]:
    """Probe Tavily Search or Research with the configured API key; return the upstream JSON."""

    if mode == "research":
        rmodel: TavilyResearchModel = tavily_research_model or settings.TAVILY_RESEARCH_MODEL
        return await tavily.research_raw(query=q, research_model=rmodel)
    return await tavily.search_raw(
        query=q,
        include_domains=source_tiers.tavily_include_domains(),
        depth=depth,
        max_results=max_results,
        restrict_domains=restrict_domains,
    )
