"""HTTP response schemas exposed by the FastAPI layer."""

from __future__ import annotations

from typing import Any, cast

from pydantic import BaseModel, ConfigDict, Field

_HEALTH_EXAMPLE: dict[str, str] = {"status": "ok"}


class HealthResponse(BaseModel):
    """Body of `GET /health`."""

    model_config = ConfigDict(
        json_schema_extra=cast(Any, {"example": _HEALTH_EXAMPLE}),
    )

    status: str = "ok"


# Realistic (abbreviated) sample for /docs and OpenAPI `example` on GeneratePlanResponse
_GENERATE_PLAN_EXAMPLE: dict[str, Any] = {
    "plan_id": "plan-a1b2c3d-4e5f-6789-0abc-def012345678",
    "request_id": "4f2e1d0c9b8a7f6e5d4c3b2a10987654",
    "qc": {
        "novelty": "similar_work_exists",
        "references": [
            {
                "title": "Trehalose as a cryoprotectant for HeLa and other adherent cell lines",
                "url": "https://www.sciencedirect.com/science/article/pii/S00112240",
                "doi": "10.1006/cryo.2001.2316",
                "why_relevant": (
                    "Compares disaccharide cryoprotectants and viability readouts post-thaw."
                ),
                "tier": "tier_1_peer_reviewed",
                "verified": True,
                "verification_url": "https://www.sciencedirect.com/science/article/pii/S00112240",
                "confidence": "high",
                "is_similarity_suggestion": False,
            }
        ],
        "similarity_suggestion": None,
        "confidence": "medium",
        "tier_0_drops": 0,
    },
    "plan": {
        "plan_id": "plan-a1b2c3d-4e5f-6789-0abc-def012345678",
        "hypothesis": (
            "Cryopreservation of HeLa cells in DMEM with 10% trehalose improves "
            "post-thaw viability vs equimolar sucrose (trypan blue, 24 h)."
        ),
        "protocol": [
            {
                "order": 1,
                "technique": "Pre-equilibration of cells with cryoprotectant in DMEM",
                "source_url": "https://www.sciencedirect.com/science/article/pii/S00112240",
            }
        ],
        "materials": [
            {
                "reagent": "D-(+)-Trehalose dihydrate",
                "vendor": "Sigma-Aldrich",
                "sku": "T9531",
                "qty": 1.0,
                "qty_unit": "g",
                "unit_cost_usd": 12.5,
            }
        ],
        "budget": {
            "items": [{"label": "Trehalose and media (planning est.)", "cost_usd": 200.0}],
            "total_usd": 200.0,
            "currency": "USD",
        },
    },
    "grounding_summary": {
        "verified_count": 4,
        "unverified_count": 1,
        "tier_0_drops": 0,
    },
    "used_prior_feedback": False,
    "prompt_versions": {
        "literature_qc.md": "8f3c2a1b9d0e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0",
        "feedback_relevance.md": "1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2",
        "experiment_planner.md": "2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3",
    },
}


class GeneratePlanResponse(BaseModel):
    """Envelope returned by `POST /experiment-plan` and `GET /plans/{id}`.

    The `qc` field is the stored **LiteratureQCResult** (see `components.schemas`
    in `/openapi.json`): `references` are HTTP-verified only; when that list is
    empty, `similarity_suggestion` may hold one unverified similar link
    (`is_similarity_suggestion` true on that object). `plan` and `grounding_summary`
    remain typed as `Any` here for doc brevity.
    """

    model_config = ConfigDict(
        json_schema_extra=cast(Any, {"example": _GENERATE_PLAN_EXAMPLE}),
    )

    plan_id: str | None = None
    request_id: str
    qc: Any
    plan: Any | None = None
    grounding_summary: Any
    used_prior_feedback: bool = False
    """True when at least one past few-shot correction was retrieved and passed to the planner."""
    prompt_versions: dict[str, str] = Field(default_factory=dict)
