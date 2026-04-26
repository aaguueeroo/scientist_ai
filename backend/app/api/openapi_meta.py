"""OpenAPI (Swagger) metadata for `GET /docs` and `GET /redoc`.

The FastAPI app uses these tags, description, and schema examples on models/routes
so the interactive API docs show realistic request/response samples.
"""

from __future__ import annotations

# Shown at the top of /docs and /redoc. Avoid GFM tables: Swagger UI's markdown
# often does not render them and shows raw pipes, which looks broken.
API_DESCRIPTION = (
    "## AI Scientist: HTTP API\n\n"
    "Turns a **research question** into a **literature novelty check** and an "
    "**experiment plan** with verifiable sources (Tier 1 and 2) and optional "
    "supplier SKU checks.\n\n"
    "### Typical flow\n\n"
    "1. **POST /literature-review** - JSON body: `query`, `request_id`. The "
    "response is **Server-Sent Events** (media type `text/event-stream`); read "
    "each `data:` line as JSON. The last `review_update` event includes "
    "`literature_review_id`. Each `sources[]` item may include `verified`, "
    "`unverified_similarity_suggestion`, and `tier` (see `LiteratureReviewSseSource` "
    "in the OpenAPI components). When there are no verified references, a single "
    "unverified similar link may appear. Stored `qc` (including `similarity_suggestion`) "
    "matches `LiteratureQCResult` in `components.schemas`.\n"
    "2. **POST /experiment-plan** - Send the same `query` and that "
    "`literature_review_id`. JSON body includes `plan_id`, `request_id`, `qc`, "
    "`plan`, `grounding_summary`, `prompt_versions` on success.\n"
    "3. Optional: **POST /feedback** for corrections. **GET /plans/{plan_id}** "
    "reloads a saved plan snapshot.\n\n"
    "### Docs and machine-readable spec\n\n"
    "- **/docs** - Interactive Swagger UI (JSON bodies; SSE is awkward in "
    "Try it out).\n"
    "- **/redoc** - Same API, ReDoc layout.\n"
    "- **/openapi.json** - OpenAPI 3 JSON for code generators.\n\n"
    "**Tracing:** set header **X-Request-ID** (or use the value returned in the "
    "response). Error bodies are **ErrorResponse** with `code`, `message`, "
    "`details`, `request_id`."
)

# Tag metadata (order matches include_router in main.py for grouping)
OPENAPI_TAGS: list[dict[str, str]] = [
    {
        "name": "Health",
        "description": "Liveness for load balancers and smoke tests.",
    },
    {
        "name": "Debug",
        "description": (
            "Operator endpoints (Tavily probe). `GET /debug/tavily` is raw upstream JSON; "
            "with `restrict_domains=true` (default) the allowlist can return empty results "
            "while the main pipeline may still run an internal unrestricted Tavily for "
            "unverified similar links. Not for production UI; costs money / quota."
        ),
    },
    {
        "name": "Literature",
        "description": (
            "Agent 1: domain-restricted Tavily, optional open-web Tavily last resort, "
            "gpt-4.1-mini, citation resolver. `references` are verified only; one "
            "`similarity_suggestion` may be stored when that list is empty. SSE "
            "`sources` mirror **LiteratureReviewSseSource**; stored `qc` is **LiteratureQCResult**."
        ),
    },
    {
        "name": "Experiment plan",
        "description": (
            "Novelty gate, feedback few-shots, Agent 3 plan, grounding. "
            "Needs a prior `literature_review_id`."
        ),
    },
    {
        "name": "Plans",
        "description": (
            "Read a saved GeneratePlanResponse from SQLite (same shape as "
            "POST /experiment-plan success)."
        ),
    },
    {
        "name": "Feedback",
        "description": (
            "Store a correction; Agent 2 may retrieve it by `domain_tag` later."
        ),
    },
]
