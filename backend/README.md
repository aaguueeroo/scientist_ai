# The AI Scientist — backend

## What this is

The **AI Scientist** backend turns a natural-language scientific hypothesis into (1) a literature novelty check and (2) a structured experiment plan: protocol, materials (with verifiable catalog references), budget, timeline, and validation. The product brief is in the repo root at `04_The_AI_Scientist.docx.pdf`. Runtime shape matches `docs/architecture.svg`: FastAPI → runtime orchestrator → runtime Agent 1 (Tavily + `gpt-4.1-mini`) → novelty gate → runtime Agent 2 (feedback + `gpt-4.1-mini`) → runtime Agent 3 (`gpt-4.1` structured outputs) → verified JSON plan + SQLite persistence. A Flutter app in `../frontend/` is out of scope for this package.

## Runtime architecture

```
Scientist hypothesis (plain English)
        |
        v
   FastAPI                    POST /literature-review, POST /experiment-plan, POST /feedback, GET /plans/{id}, GET /health
        |
        v
  Runtime orchestrator         sequences agents, shared pipeline_state
        |
        v
  Runtime Agent 1              Tavily (include_domains) + open-web fallback, gpt-4.1-mini
        |                      -> LiteratureQCResult + NoveltyLabel (Tavily score>0.6 can verify)
        v
  Novelty gate                 not_found | similar_work_exists | exact_match
        |                      (exact_match => return QC only; skip Agents 2 & 3)
        v
  Runtime Agent 2              FeedbackRepo few-shots + gpt-4.1-mini
        |
        v
  Runtime Agent 3              gpt-4.1 JSON-schema structured outputs
        |                      -> ExperimentPlan; citation + catalog resolvers
        v
  JSON response + plan store   SQLite (plans + feedback), prompt_versions stamped
```

## Prerequisites

- **Python** 3.11 or 3.12 (see `pyproject.toml`).
- **OpenAI** API key and **Tavily** API key for a live server.
- **uv** (recommended) or another PEP 621 installer, plus **PowerShell** on Windows (this doc assumes that). On Linux or macOS, use `source .venv/bin/activate` instead of `Activate.ps1` and the same `uv` / `pytest` commands from the `backend/` directory.

## Install

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
# Recommended (uses uv.lock):
uv sync --group dev
# If you do not use uv:
# pip install -e ".[dev]"
```

## Configure

Required environment variables (see `app/config/settings.py` and `backend/.env.example`):

| Variable | Purpose |
|----------|---------|
| `OPENAI_API_KEY` | OpenAI access |
| `TAVILY_API_KEY` | Tavily API key (Search and/or Research; see below) |
| `TAVILY_RETRIEVAL_MODE` | `search` or `research` (default **`search`**) — which Tavily product Agent 1 uses |
| `TAVILY_RESEARCH_MODEL` | `mini`, `pro`, or `auto` (default `mini`); only used when `TAVILY_RETRIEVAL_MODE=research` |
| `MAX_REQUEST_USD` | Per-request cost ceiling (default `0.60`) |
| `RATE_LIMIT_PER_MIN` | Per-IP cap on `POST` routes (default `30`) |
| `DATABASE_URL` | Async SQLAlchemy URL (default `sqlite+aiosqlite:///./ai_scientist.db`) |

Inline in PowerShell:

```powershell
$env:OPENAI_API_KEY = "sk-..."
$env:TAVILY_API_KEY = "tvly-..."
$env:MAX_REQUEST_USD = "0.60"
```

Or create `backend/.env` (loaded by `pydantic-settings`):

```env
OPENAI_API_KEY=sk-replace-me
TAVILY_API_KEY=tvly-replace-me
MAX_REQUEST_USD=0.60
RATE_LIMIT_PER_MIN=30
DATABASE_URL=sqlite+aiosqlite:///./ai_scientist.db
```

## Protocol repositories and how protocols are handled

The product brief (`04_The_AI_Scientist.docx.pdf`) and internal design docs name **peer-reviewed and community protocol sources** (for example **protocols.io**, **Bio-protocol**, **JOVE**, **OpenWetWare**). In this codebase they are **not** integrated as separate databases or APIs.

**What exists today**

- **`app/config/source_tiers.yaml`** lists hostnames used for **trust classification** and for the **Tavily domain allowlist** (union of Tier 1 + Tier 2 + supplier hosts). Examples that match the brief’s intent:
  - **Tier 1:** `bio-protocol.org`, `jove.com` (peer-reviewed-style protocol outlets).
  - **Tier 2:** `protocols.io`, `openwetware.org` (community / preprint-style).
- **Tavily** (Search or Research; see [Tavily: Search vs Research](#tavily-search-vs-research-api)) only returns **web results** whose URLs fall on those allowed hosts. There is **no** direct “query protocols.io” API in the app.
- **Runtime Agent 1** (literature QC) feeds search/research hits into an LLM; **Runtime Agent 3** outputs a structured `protocol: ProtocolStep[]` in `ExperimentPlan` (ordered steps, optional `source_url` / `source_doi` per step).
- **Grounding** (`app/verification/grounding.py`) does **not** import from protocol repos. It runs the **citation resolver** on reference URLs/DOIs and the **catalog resolver** on materials (Sigma/Thermo-style SKUs on supplier pages). Protocol steps with sources are checked like citations; steps without `source_url` / `source_doi` are left unverified.

So **protocols.io and similar sites appear only as allowed domains for retrieval and as normal HTTPS citations**, not as dedicated protocol-CRUD services.

## Request and plan identifiers

**`request_id` (HTTP + tracing)**

- **Scope:** One value per **HTTP request** to the API (each of `POST /literature-review`, `POST /experiment-plan`, `POST /feedback`, `GET /plans/{id}`, etc. has its own id).
- **Origin:** The middleware (`app/api/middleware.py`) sets `request_id` from the `X-Request-ID` header if the client sent one; otherwise it generates a **32-character hex** string (UUID without hyphens).
- **Response:** The same `request_id` is returned in the JSON body on success and on domain errors, and the **`X-Request-ID`** response header is set to the same value (`REQUEST_ID_HEADER` in the middleware). Logs (`http.request.complete`, agent lines, and error lines) include this id so you can **correlate a client call, a log file, and a support ticket**.
- **Persistence:** `request_id` is **stored** on:
  - **`plans` table** when a plan is saved (`POST /experiment-plan` success): `request_id` is the one for that experiment-plan request.
  - **`feedback` table** when feedback is saved: `request_id` is the one for that feedback request (not the original plan’s id unless the client reuses the same header for both calls, which is optional).

**`plan_id` (resource identity for a completed experiment plan)**

- **Scope:** One **per generated plan** in the `ExperimentPlan` / `GeneratePlanResponse` model. The LLM (Agent 3) emits `plan_id` in structured output; it should be a **stable string identifier** (tests often use UUID-like strings; the schema allows up to 200 characters).
- **Uniqueness:** Treated as the **primary key** in SQLite (`app/storage/models.py` — `PlanRow.plan_id`). A second `POST /experiment-plan` (after a new literature review) will produce a **new** `plan_id` in normal operation.
- **Retrieval:** `GET /plans/{plan_id}` loads the **serialized JSON snapshot** of `GeneratePlanResponse` as stored on save: same `plan_id`, `request_id` from the request that **saved** the row, `qc`, `plan`, `grounding_summary`, `prompt_versions`, etc. Unknown ids return `404` with the closed error set (`validation_error`).

**Working with multiple plans and requests**

- **New hypothesis** → new HTTP request (new `request_id` unless you force reuse via header) → new pipeline run → new `plan_id` when a plan is produced, then saved with that `request_id` on the plan row.
- **Feedback** → `POST /feedback` with **`plan_id`** pointing at the plan you are correcting. Agent 2 uses the feedback store for few-shots; it does not rewrite stored plans by id. The feedback row carries its own `request_id` for that submission.
- **Idempotency:** The server does not deduplicate by hypothesis text. Two identical literature + experiment flows still create **two** runs (two `request_id` values on each step) and, if both succeed, **two** stored plans (two `plan_id` values) unless the model collides on `plan_id` (unlikely).

**`literature_review_id` (linking step 1 → 2)**

- **Origin:** Returned in the final SSE `review_update` event from `POST /literature-review` (field `data.literature_review_id`).
- **Use:** Pass the **same** `query` string (after trim) and this id in the body of `POST /experiment-plan`. The server loads the stored Agent-1 `LiteratureQCResult` by id and must match `query` to the text saved with that review (HTTP **422** if unknown id or text mismatch).

## Tavily: Search API vs Research API

- **Tavily Search** (`POST /search`, used by `tavily-python`’s `AsyncTavilyClient.search`) returns a list of result rows (title, URL, content snippet, score) for **one** query, with `include_domains`, `search_depth` (`basic` / `advanced`), etc. Used when **`TAVILY_RETRIEVAL_MODE=search`**.
- **Tavily Research** (`POST /research` + `GET /research/{request_id}`) runs a **longer, multi-step research task** and returns a report plus a **`sources`** list. The backend (when **`TAVILY_RETRIEVAL_MODE=research`**) maps those sources into the same `TavilyHit` shape Agent 1 expects, then **filters URLs** to the same tier-derived **hostname allowlist** as Search (`source_tiers.yaml`). `search_depth` does not apply to Research; **`TAVILY_RESEARCH_MODEL`** sets `mini` / `pro` / `auto`. **Default** is **Search** (`TAVILY_RETRIEVAL_MODE=search`); set **`research`** when you want the longer report-style flow (slower, typically more expensive).

The **debug** route `GET /debug/tavily` supports **`mode=search`** (raw `/search` JSON, uses `depth` and `max_results`) and **`mode=research`**. For Search, **`restrict_domains=false`** omits `include_domains` (open web); the default **`restrict_domains=true`** matches Agent 1’s allowlist and can return empty `results` for long queries—Agent 1 may still run an **internal** open-web Tavily call for high-relevance fallbacks, which this route does **not** reflect. See route description in `/docs` for `GET /debug/tavily`.

## Run the server

From `backend/` with the venv active:

```powershell
uv run uvicorn app.main:app --reload --port 8000
```

Smoke check:

```powershell
Invoke-RestMethod -Uri "http://localhost:8000/health" -Method Get
# {"status":"ok"}
```

OpenAPI UI: [http://localhost:8000/docs](http://localhost:8000/docs)

## Logging

The server uses **structlog** with one JSON object per line on stdout. Every request ends with an `http.request.complete` line (method, path, status, latency, `request_id`, costs, and verification stats).

**Set verbosity** in `backend/.env` (or the environment) with:

```text
LOG_LEVEL=INFO
```

- **`INFO` (default):** app lifecycle (`app.startup.*`, `app.shutdown.*`), **pipeline** milestones (`pipeline.begin`, `pipeline.literature_qc.done`, `pipeline.novelty_gate.stop`, `pipeline.feedback_relevance.*`, `pipeline.experiment_planner.done`, `pipeline.grounding.done`, `pipeline.complete`), and **all errors** as structured lines (`app.http.domain_error`, `app.http.validation_error`, `app.http.unhandled_exception` with a truncated traceback for unexpected failures).
- **`DEBUG`:** everything at `INFO`, plus:
  - **`http.request.begin`** — method, path, query string (truncated), `content_type`, client host.
  - **`http.request.response_start`** — status, `latency_ms` to when the response object is returned (**for `text/event-stream`, this is *not* the full body**; use `app.literature_review.stream_total` for that).
  - **`app.literature_review.input` / `agent_result` / `sse_chunk` / `stream_total`** — query preview, QC summary, each SSE line preview, and total wall time for the stream including Agent 1.
  - **`app.experiment_plan.input` / `output`** — query preview, `literature_review_id`, pipeline time, `plan_id` / novelty.
  - **`pipeline.*.step_ms`** — per-phase `elapsed_ms` (literature, novelty gate, feedback, experiment planner, grounding).
- **`LOG_DEBUG_PREVIEW_CHARS`** (default `400`) — max length of `query_preview` and similar string fields in those DEBUG lines (set to `0` to omit long previews).

Invalid `LOG_LEVEL` values fall back to `INFO`. Third-party HTTP client libraries (httpx, OpenAI SDK) stay at **INFO** even when the app is `DEBUG`, to avoid huge noisy logs; raise them only if you are debugging a transport issue (change `app/observability/logging.py` → `_set_stdlib_log_levels` if needed).

**Run** with logs visible in the same terminal (PowerShell), for example:

```powershell
cd backend
# optional: $env:LOG_LEVEL = "DEBUG"
uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

`uvicorn`’s own access and error loggers follow `LOG_LEVEL` (so at `DEBUG` you get more from uvicorn; request lines remain JSON from structlog for normal handler paths).

## OpenAI structured outputs (Pydantic)

Runtime agents that call `openai.chat.completions.parse` must use Pydantic models that satisfy [OpenAI’s JSON Schema subset](https://developers.openai.com/api/docs/guides/structured-outputs#supported-schemas). In this repo, every model in those `response_format` trees subclasses `app.schemas.openai_structured_model.OpenAIStructuredModel` (`extra="forbid"` so each object gets `additionalProperties: false`). URL fields are plain `str` (never `pydantic.HttpUrl`, which emits unsupported `format: "uri"`). Tests in `tests/schemas/test_openai_structured_schemas.py` assert compliance for `NoveltyClaim`, `ExperimentPlan`, and Agent 2 claim types.

## API reference

### `POST /literature-review`

**Purpose:** Run **Agent 1** (domain-restricted Tavily, optional open-web Tavily last resort, `gpt-4.1-mini`, HTTP citation resolver), persist the `LiteratureQCResult` under a new `literature_review_id`, and stream **Server-Sent Events** (`text/event-stream`). Each line is `data: ` + JSON with `event` (`review_update` or `error`) and `data` (see below). The final `review_update` includes `data.literature_review_id` (and `data.is_final: true`).

**Request (JSON):**

- `query` — hypothesis text (1–4000 chars).
- `request_id` — client-owned correlation id (1–200 chars), e.g. from `LiteratureReviewRequestDto`; included in server logs as `client_request_id`. The HTTP **trace** id is still **`X-Request-ID`** (response header) and is what the DB stores on the row as `request_id`.

**Agent 1 result logic (for UI / stored `qc`):**

- `references` — up to 3 **HTTP resolver–verified** rows **or** rows accepted because Tavily’s relevance **score for that work is &gt; 0.6** (strict), when the resolver does not confirm. Tier-3 URLs can also be “verified” this way (no HTTP GET to the publisher). OpenAPI documents `LiteratureQCResult` in `components.schemas` (`/openapi.json`).
- `similarity_suggestion` — **optional**; only when `references` is still empty. One last-resort link (Tavily + LLM fallbacks) marked `is_similarity_suggestion: true` in JSON (not shown as verified).

**SSE `data.sources[]` (Flutter `Source` shape):** each item includes `author`, `title`, `date_of_publication` (placeholder `1970-01-01` today), `abstract`, `doi`, and additionally **`verified`**, **`unverified_similarity_suggestion`**, and **`tier`** (e.g. `tier_1_peer_reviewed`, `tier_3_general_web`). Unverified similar-only rows are labeled in `author` / `abstract` and `unverified_similarity_suggestion: true`. See `LiteratureReviewSseSource` in `/openapi.json`.

**PowerShell (Invoke-WebRequest reads the stream as text; for production, use an SSE-capable client):**

```powershell
$lit = '{"query":"Cryopreservation of HeLa cells in DMEM supplemented with 10% trehalose yields a significantly higher post-thaw viability than equimolar sucrose, measured by trypan-blue exclusion 24 hours after thaw.","request_id":"cli-1"}'
Invoke-WebRequest -Uri "http://localhost:8000/literature-review" -Method Post -Body $lit -ContentType "application/json" -Headers @{"Accept"="text/event-stream"}
```

**curl (same):**

```powershell
curl.exe -s -N -X POST "http://localhost:8000/literature-review" -H "Content-Type: application/json" -H "Accept: text/event-stream" -d "{\"query\":\"Cryopreservation of HeLa cells in DMEM supplemented with 10% trehalose yields a significantly higher post-thaw viability than equimolar sucrose, measured by trypan-blue exclusion 24 hours after thaw.\",\"request_id\":\"cli-1\"}"
```

### `POST /experiment-plan`

**Purpose:** Load the stored literature QC by `literature_review_id`, run the **novelty gate** and (if not `exact_match`) **Agents 2–3**, resolvers, and return `GeneratePlanResponse`; persists the plan when present.

**Request (Pydantic v2):**

```python
from pydantic import BaseModel, Field

class ExperimentPlanHttpRequest(BaseModel):
    query: str = Field(min_length=10, max_length=2000)
    literature_review_id: str = Field(min_length=1, max_length=80)
```

**Response (success, 200):**

```python
class GeneratePlanResponse(BaseModel):
    plan_id: str | None
    request_id: str
    qc: object  # LiteratureQCResult (references, optional similarity_suggestion, novelty, …)
    plan: object | None  # ExperimentPlan
    grounding_summary: object
    prompt_versions: dict[str, str]
```

**Errors:** `422` `validation_error` (body, unknown `literature_review_id`, or `query` mismatch), `402` `cost_ceiling_exceeded`, `422` `grounding_failed_refused`, `503` `openai_unavailable` / `tavily_unavailable`, `429` `openai_rate_limited` (rate limit uses this code), `502` `structured_output_invalid`, `500` `internal_error` — all use `ErrorResponse` (`code`, `message`, `details`, `request_id`).

**PowerShell example** (use the `literature_review_id` from the last SSE `data` line; same `query` as step 1):

```powershell
$body = '{"query":"Cryopreservation of HeLa cells in DMEM supplemented with 10% trehalose yields a significantly higher post-thaw viability than equimolar sucrose, measured by trypan-blue exclusion 24 hours after thaw.","literature_review_id":"lr-paste-from-sse"}'
Invoke-RestMethod -Uri "http://localhost:8000/experiment-plan" -Method Post -Body $body -ContentType "application/json"
```

**curl example:**

```powershell
curl.exe -s -X POST "http://localhost:8000/experiment-plan" -H "Content-Type: application/json" -d "{\"query\":\"Cryopreservation of HeLa cells in DMEM supplemented with 10% trehalose yields a significantly higher post-thaw viability than equimolar sucrose, measured by trypan-blue exclusion 24 hours after thaw.\",\"literature_review_id\":\"lr-paste-from-sse\"}"
```

### `POST /feedback`

**Purpose:** Store scientist corrections tagged by `domain_tag` for runtime Agent 2 few-shot retrieval.

**Request:**

```python
from enum import StrEnum
from pydantic import BaseModel, ConfigDict, Field

class DomainTag(StrEnum):
    DIAGNOSTICS_BIOSENSOR = "diagnostics-biosensor"
    MICROBIOME_MOUSE_MODEL = "microbiome-mouse-model"
    CELL_BIOLOGY_CRYOPRESERVATION = "cell-biology-cryopreservation"
    SYNTHETIC_BIOLOGY_BIOELECTRO = "synthetic-biology-bioelectro"
    OTHER = "other"

class FeedbackRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    plan_id: str
    domain_tag: DomainTag | None = None
    corrected_field: str
    before: str
    after: str
    reason: str
```

**Response (200):**

```python
class FeedbackResponse(BaseModel):
    feedback_id: str
    request_id: str
    accepted: bool
    domain_tag: DomainTag
```

**PowerShell example:**

```powershell
$fb = @{
  plan_id = "00000000-0000-4000-8000-000000000001"
  domain_tag = "cell-biology-cryopreservation"
  corrected_field = "materials[0].catalog_number"
  before = "OLD-SKU"
  after = "567890"
  reason = "Verified on supplier site"
} | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:8000/feedback" -Method Post -Body $fb -ContentType "application/json"
```

**curl example:**

```powershell
curl.exe -s -X POST "http://localhost:8000/feedback" -H "Content-Type: application/json" -d "{\"plan_id\":\"00000000-0000-4000-8000-000000000001\",\"domain_tag\":\"cell-biology-cryopreservation\",\"corrected_field\":\"materials[0].catalog_number\",\"before\":\"OLD-SKU\",\"after\":\"567890\",\"reason\":\"Verified on supplier site\"}"
```

### `GET /plans/{id}`

**Purpose:** Return a previously persisted `GeneratePlanResponse` by `plan_id`.

**Response:** same as `POST /experiment-plan` (200). **404** with `code: validation_error` if the id is unknown (closed error set; no separate `not_found` code).

**PowerShell example:**

```powershell
Invoke-RestMethod -Uri "http://localhost:8000/plans/00000000-0000-4000-8000-000000000001" -Method Get
```

**curl example:**

```powershell
curl.exe -s "http://localhost:8000/plans/00000000-0000-4000-8000-000000000001"
```

### `GET /health`

**Purpose:** Liveness for load balancers and manual smoke tests.

**Response:**

```python
class HealthResponse(BaseModel):
    status: str = "ok"
```

**PowerShell example:**

```powershell
Invoke-RestMethod -Uri "http://localhost:8000/health" -Method Get
```

**curl example:**

```powershell
curl.exe -s "http://localhost:8000/health"
```

## Sample data

Use the same `query` in **`POST /literature-review`** and **`POST /experiment-plan`** (after you copy `literature_review_id` from the stream). Bodies (the four brief hypotheses):

**1 — CRP paper-based biosensor**

```json
{
  "query": "A paper-based electrochemical biosensor can detect C-reactive protein (CRP) in unprocessed whole blood within 10 minutes at the < 1 mg/L sensitivity needed for sepsis screening."
}
```

**2 — *Lactobacillus rhamnosus* GG / C57BL/6**

```json
{
  "query": "Daily oral gavage of Lactobacillus rhamnosus GG (ATCC 53103) to C57BL/6 mice for 14 days increases relative abundance of LGG in cecal contents by ≥ 1 log10 copies per gram compared with vehicle controls, measured by 16S rRNA qPCR."
}
```

**3 — Trehalose vs sucrose / HeLa**

```json
{
  "query": "Cryopreservation of HeLa cells in DMEM supplemented with 10% trehalose yields a significantly higher post-thaw viability than equimolar sucrose, measured by trypan-blue exclusion 24 hours after thaw."
}
```

**4 — *Sporomusa ovata* CO₂ fixation**

```json
{
  "query": "Sporomusa ovata grown on a graphite cathode at -400 mV vs SHE fixes CO2 into acetate at a Coulombic efficiency above 80%, sustained over a 7-day batch run."
}
```

**Example `POST /feedback` after a trehalose run** (replace `plan_id` with the `plan_id` from your `POST /experiment-plan` response):

```json
{
  "plan_id": "paste-your-plan-uuid-here",
  "domain_tag": "cell-biology-cryopreservation",
  "corrected_field": "materials[0].catalog_number",
  "before": "H1234",
  "after": "H5678",
  "reason": "Re-verified on Thermo Fisher product page; update few-shot for next runs."
}
```

## End-to-end walkthrough (trehalose)

1. **Start the server** (see **Run the server**). Ensure keys are set.
2. **Run literature review** with `POST /literature-review`, the `query` from **Sample data** §3, and a `request_id` for your client session. Read SSE until you have `data.literature_review_id`.
3. **Request the experiment plan** with `POST /experiment-plan` using the same `query` and that `literature_review_id`. You should receive `qc` (with novelty), `grounding_summary`, and a full `plan` (unless the novelty branch returns QC-only), plus `plan_id` and `prompt_versions`.
4. **Send feedback** with `POST /feedback` and the `plan_id` you received. Response includes `feedback_id` and `accepted: true`.
5. **Re-submit** a new literature + experiment flow with a **related** `query` (e.g. same trehalose text with a minor tweak) so Agent 2 can surface prior feedback. Compare `plan.materials` or protocol notes (see `tests` Step 45 for the automated expectation).

**Commands (abbreviated):**

```powershell
# 1) literature-review (see SSE; extract literature_review_id from last data line)
# 2) experiment-plan
$h = '{"query":"Cryopreservation of HeLa cells in DMEM ...","literature_review_id":"lr-..."}'
$r = Invoke-RestMethod "http://localhost:8000/experiment-plan" -Method Post -Body $h -ContentType "application/json"
$pid = $r.plan_id
# ... POST /feedback with $pid, then repeat 1) + 2) with a related query
```

## Project structure

- `app/main.py` — FastAPI factory, lifespan (OpenAI, Tavily, DB).
- `app/api/` — routes (`literature_review`, `experiment_plan`, `feedback`, `plans`, `health`), `errors`, `middleware`, `deps`.
- `app/runtime/` — `orchestrator.py`, `novelty_gate.py`, `pipeline_state.py`.
- `app/agents/` — `literature_qc`, `feedback_relevance`, `experiment_planner`.
- `app/clients/` — OpenAI and Tavily abstractions (real + fakes for tests).
- `app/storage/` — async SQLite, `PlanRow` / `FeedbackRow` / `LiteratureReviewRow`, repos.
- `app/schemas/` — Pydantic API and domain models, `SourceTier`, MIQE, errors.
- `app/prompts/` — `literature_qc.md`, `feedback_relevance.md`, `experiment_planner.md` + `loader.py`.
- `app/config/` — `settings.py`, `source_tiers.yaml`.
- `app/verification/` — citation and catalog resolvers, grounding.
- `tests/` — unit, API, e2e cassettes, injection tests, `test_readme.py`.
- `scripts/check.ps1` — canonical `pytest` + ruff + mypy gate.

## How it works (request flow)

`POST /literature-review` runs **Agent 1** and stores QC for `literature_review_id`. `POST /experiment-plan` hits FastAPI with a precached `LiteratureQCResult` (no second Agent-1 run), then the **runtime orchestrator** builds `pipeline_state`. The **novelty gate** either stops with QC only (`exact_match`) or continues. If it continues, **runtime Agent 2** reads `FeedbackRepo` for the tagged domain and passes few-shots to **runtime Agent 3** (`gpt-4.1` structured JSON). Resolvers verify DOIs/URLs and catalog SKUs; if grounding rules fail, the API returns `grounding_failed_refused`. On success, **PlansRepo** persists the `GeneratePlanResponse` with `schema_version` and `prompt_versions`. For a diagram reference, use `docs/architecture.svg` in the repo root.

## Trust & anti-hallucination guarantees

- **SourceTier** (`TIER_1_PEER_REVIEWED`, `TIER_2_PREPRINT_OR_COMMUNITY`, `TIER_3_GENERAL_WEB`, `TIER_0_FORBIDDEN`) is assigned in code from `app/config/source_tiers.yaml`, not by the LLM. Tier 0 is dropped; Tier 3 is not used for primary novelty/grounding.
- **Citation and catalog resolvers** (`app/verification/`) must mark items `verified` before they are treated as trustworthy; the global **50% unverified materials** rule triggers a refusal.
- **Role prompts** live under `app/prompts/`, are loaded by `loader.py`, and are hashed into `prompt_versions` — they are **never** concatenated with user text in the system channel.
- **Adversarial tests** under `tests/injection/` ensure injection strings do not become instructions or raise forbidden tiers.
- Reject fabricated outputs: if nothing verifies, the API refuses with `grounding_failed_refused` rather than inventing DOIs or SKUs.

## Observability & error contract

Each runtime agent call logs one **JSON** line via `structlog` with: `agent`, `model`, `prompt_hash` (role file sha256), `prompt_tokens`, `completion_tokens`, `latency_ms`, `verified_count`, `tier_0_drops`, `request_id` (and related orchestrator fields as implemented). The HTTP layer emits a per-request line with `event="http.request.complete"`. Find rows by `request_id` in logs and in persisted plan/feedback records.

**`ErrorCode` (8 only):** `validation_error` (422; includes unknown `plan_id` on GET), `tavily_unavailable` (503), `openai_unavailable` (503), `openai_rate_limited` (429; also per-IP rate limit on POST), `structured_output_invalid` (502), `grounding_failed_refused` (422), `cost_ceiling_exceeded` (402), `internal_error` (500).

**Example `ErrorResponse` body (grounding refusal):** `message` and `details` explain counts; see structlog `app.http.domain_error` with full `details`.

```json
{
  "code": "grounding_failed_refused",
  "message": "After automated verification, nothing in the plan could be marked verified: ...",
  "details": {
    "reason": "zero_verified_items",
    "verified_count": 0,
    "unverified_count": 12,
    "tier_0_drops": 0,
    "references_in_plan": 2,
    "protocol_steps": 5,
    "materials_in_plan": 8
  },
  "request_id": "01HMXYZ..."
}
```

## Development

- **Canonical check:** from repo root, `pwsh backend/scripts/check.ps1` (runs `pytest -q`, `ruff format .`, `ruff check .`, `mypy --strict .` from `backend/`).
- **Partial runs:** `uv run pytest -q`, `uv run ruff check .`, `uv run mypy --strict .`.
- **TDD:** red → green → refactor (see `.cursor/rules/tdd.mdc`); new behavior starts with a failing test in `tests/`.
- **Cassettes:** default suite is **offline**; to re-record against live APIs use `uv run pytest -m live --record-mode=once` with keys (explicit; never by default). Commit cassettes under `tests/cassettes/`.
- **Saving OpenAI / Tavily spend:** `pytest` uses fakes and **does not** call the real APIs (no token cost). Every manual `curl` or Postman hit to `uvicorn` on `/literature-review` and `/experiment-plan` runs the real pipeline (OpenAI + Tavily + supplier HTTP) and **does** cost. Prefer `uv run pytest -q tests/api/test_experiment_plan.py` (or the full suite) while iterating on code; use the live server only when you need real model + search behavior.

## Troubleshooting

- **Missing `OPENAI_API_KEY` / `TAVILY_API_KEY`:** set env or `.env` in `backend/`; restart uvicorn.
- **OpenAI 429 / rate limit:** same as application `openai_rate_limited` — back off; POST rate limits also return 429 with that code.
- **Tavily empty / allowlist issues:** check `TAVILY_API_KEY` and `source_tiers` domains in logs.
- **SQLite file path (Windows):** default `./ai_scientist.db` under `backend/`; override `DATABASE_URL` if needed.
- **Port 8000 in use:** `uvicorn ... --port 8001`.
- **`structured_output_invalid`:** model returned non-conforming JSON for Agent 3 — inspect logs, prompts, and cassette drift.
- **`cost_ceiling_exceeded`:** increase `MAX_REQUEST_USD` carefully for long plans; see `settings.py`.
- **`grounding_failed_refused`:** read `message` and `details.reason` (`zero_verified_items` = no verified refs/steps/materials after HTTP checks; `too_many_unverified_materials` = unverified_count / materials ≥ 0.5). Fix URLs, DOI resolution, supplier name + SKU for Sigma/Thermo patterns, or Tier-0 drops.
- **Tests pass locally but CI fails cassettes:** re-record with the `live` marker on a dev machine, review diff, commit.

---

The AI Scientist (backend) | Spec: `04_The_AI_Scientist.docx.pdf` | Architecture: `docs/architecture.svg`
