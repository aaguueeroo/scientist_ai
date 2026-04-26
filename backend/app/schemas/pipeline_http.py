"""HTTP request bodies for the literature + experiment plan pipeline (FastAPI)."""

from __future__ import annotations

from typing import Any, cast

from pydantic import BaseModel, ConfigDict, Field

_LITERATURE_REQUEST_EXAMPLE: dict[str, str] = {
    "query": (
        "Cryopreservation of HeLa cells in DMEM with 10% trehalose yields higher "
        "post-thaw viability than equimolar sucrose, measured 24 h after thaw by trypan blue."
    ),
    "request_id": "req_1745619123456_flutter",
}

_SSE_SOURCE_EXAMPLE_SIMILARITY: dict[str, str | bool] = {
    "author": "Unverified (similarity suggestion)",
    "title": "Related work on disaccharide cryoprotectants",
    "date_of_publication": "1970-01-01",
    "abstract": (
        "[Unverified — similar content only, not HTTP-verified] "
        "Possibly related study from open-web search."
    ),
    "doi": "10.0000/unspecified",
    "verified": False,
    "unverified_similarity_suggestion": True,
    "tier": "tier_3_general_web",
}

_SSE_SOURCE_EXAMPLE_VERIFIED: dict[str, str | bool] = {
    "author": "Verified source (tier-assigned)",
    "title": "Trehalose as a cryoprotectant for HeLa cells",
    "date_of_publication": "1970-01-01",
    "abstract": "Compares disaccharide cryoprotectants and viability readouts post-thaw.",
    "doi": "10.1006/cryo.2001.2316",
    "verified": True,
    "unverified_similarity_suggestion": False,
    "tier": "tier_1_peer_reviewed",
}

_EXPERIMENT_PLAN_REQUEST_EXAMPLE: dict[str, str] = {
    "query": (
        "Cryopreservation of HeLa cells in DMEM with 10% trehalose yields higher "
        "post-thaw viability than equimolar sucrose, measured 24 h after thaw by trypan blue."
    ),
    "literature_review_id": "lr-7f2e1d0c9b8a6f5e4d3c2b1a0f9e8d7c6b5a4321",
}


class LiteratureReviewHttpRequest(BaseModel):
    """`POST /literature-review` JSON body (aligns with `LiteratureReviewRequestDto`).

    `query` is the research text. `request_id` is a client-owned correlation id (logged
    as `client_request_id`); the server trace and DB row `request_id` use `X-Request-ID`
    from middleware (or a generated id when omitted).
    """

    model_config = ConfigDict(
        extra="ignore",
        json_schema_extra=cast(Any, {"example": _LITERATURE_REQUEST_EXAMPLE}),
    )

    query: str = Field(min_length=1, max_length=4000)
    request_id: str = Field(
        min_length=1,
        max_length=200,
        description="Client-owned correlation id for logs; canonical trace is X-Request-ID.",
    )


class ExperimentPlanHttpRequest(BaseModel):
    """Body for `POST /experiment-plan` (Flutter `ExperimentPlanRequestDto` field names)."""

    model_config = ConfigDict(
        extra="forbid",
        json_schema_extra=cast(Any, {"example": _EXPERIMENT_PLAN_REQUEST_EXAMPLE}),
    )

    query: str = Field(min_length=10, max_length=2000)
    literature_review_id: str = Field(
        min_length=1,
        max_length=80,
        description="Id returned in the final SSE event from `POST /literature-review`.",
    )


class LiteratureReviewSseSource(BaseModel):
    """One entry in the SSE ``data.sources`` list (``review_update``), Flutter ``Source`` shape.

    Populated from Agent 1 :class:`app.schemas.literature_qc.Reference` via
    :func:`app.api.literature_review._reference_to_fe_source` (the API does not stream raw ``Reference`` JSON).
    """

    author: str = Field(
        description=(
            "Display label for the source origin. "
            "Verified rows use a tier label; unverified similar-only rows use "
            "``Unverified (similarity suggestion)``."
        )
    )
    title: str = Field(description="Article or page title.")
    date_of_publication: str = Field(
        description="Stub date string in API responses (placeholder until enriched)."
    )
    abstract: str = Field(
        description=(
            "Snippet or rationale. May be prefixed with "
            "``[Unverified — similar content only, not HTTP-verified]`` when "
            "``unverified_similarity_suggestion`` is true."
        )
    )
    doi: str = Field(
        description="DOI or placeholder ``10.0000/unspecified`` if missing in the model."
    )
    verified: bool = Field(
        description="True when the row is resolver-verified and not a similarity-only suggestion."
    )
    unverified_similarity_suggestion: bool = Field(
        description=(
            "True when this row is the last-resort similar link: not HTTP-verified by "
            "the citation resolver, shown only if there were no verified references."
        )
    )
    tier: str = Field(
        description="Trust tier (``SourceTier``), e.g. ``tier_1_peer_reviewed`` or ``tier_3_general_web``."
    )

    model_config = ConfigDict(
        json_schema_extra=cast(Any, {"example": _SSE_SOURCE_EXAMPLE_SIMILARITY})
    )


class LiteratureReviewSseUpdateData(BaseModel):
    """JSON inside ``data`` for SSE events where ``event`` is ``review_update``."""

    is_final: bool = Field(description="True on the last cumulative chunk for this request.")
    does_similar_work_exist: bool = Field(
        description="Derived from novelty: similar / exact / not found (see `NoveltyLabel`)."
    )
    expected_total_sources: int = Field(
        description="Final count of sources in the last event; intermediate events grow ``sources``."
    )
    sources: list[LiteratureReviewSseSource] = Field(
        default_factory=list,
        description=(
            "Cumulative list of **LiteratureReviewSseSource** objects. May include "
            "at most one entry with ``unverified_similarity_suggestion: true`` when there "
            "were no verified references but a fallback link was found."
        ),
    )
    literature_review_id: str | None = Field(
        default=None,
        description="Set only on the final ``is_final: true`` event: id for `POST /experiment-plan`.",
    )

    model_config = ConfigDict(
        json_schema_extra=cast(
            Any,
            {
                "example": {
                    "is_final": True,
                    "does_similar_work_exist": True,
                    "expected_total_sources": 1,
                    "sources": [_SSE_SOURCE_EXAMPLE_VERIFIED],
                    "literature_review_id": "lr-8e7d6c5b4a39281726354a1b2c3d4e5f",
                }
            },
        )
    )
