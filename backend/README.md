# The AI Scientist — backend

## What this is

The **AI Scientist** backend turns a natural-language scientific hypothesis into (1) a literature novelty check and (2) a structured experiment plan: protocol, materials (with verifiable catalog references), budget, timeline, and validation. The product brief is in the repo root at `04_The_AI_Scientist.docx.pdf`. Runtime shape matches `docs/architecture.svg`: FastAPI → runtime orchestrator → runtime Agent 1 (Tavily + `gpt-4.1-mini`) → novelty gate → runtime Agent 2 (feedback + `gpt-4.1-mini`) → runtime Agent 3 (`gpt-4.1` structured outputs) → verified JSON plan + SQLite persistence. A Flutter app in `../frontend/` is out of scope for this package.

## Runtime architecture

```
Scientist hypothesis (plain English)
        |
        v
   FastAPI                    POST /generate-plan, POST /feedback, GET /plans/{id}, GET /health
        |
        v
  Runtime orchestrator         sequences agents, shared pipeline_state
        |
        v
  Runtime Agent 1              Tavily (include_domains from Tier1+2) + gpt-4.1-mini
        |                      -> LiteratureQCResult + NoveltyLabel
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
| `TAVILY_API_KEY` | Tavily web search |
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

## API reference

### `POST /generate-plan`

**Purpose:** Run the full pipeline (or QC-only on `exact_match`) and return an envelope with literature QC, optional `ExperimentPlan`, and grounding summary; persists the plan when present.

**Request (Pydantic v2):**

```python
from pydantic import BaseModel, Field

class GeneratePlanRequest(BaseModel):
    hypothesis: str = Field(min_length=10, max_length=2000)
```

**Response (success, 200):**

```python
class GeneratePlanResponse(BaseModel):
    plan_id: str | None
    request_id: str
    qc: object  # LiteratureQCResult
    plan: object | None  # ExperimentPlan
    grounding_summary: object
    prompt_versions: dict[str, str]
```

**Errors:** `422` `validation_error`, `402` `cost_ceiling_exceeded`, `422` `grounding_failed_refused`, `503` `openai_unavailable` / `tavily_unavailable`, `429` `openai_rate_limited` (rate limit uses this code), `502` `structured_output_invalid`, `500` `internal_error` — all use `ErrorResponse` (`code`, `message`, `details`, `request_id`).

**PowerShell example:**

```powershell
$body = '{"hypothesis":"Cryopreservation of HeLa cells in DMEM supplemented with 10% trehalose yields a significantly higher post-thaw viability than equimolar sucrose, measured by trypan-blue exclusion 24 hours after thaw."}'
Invoke-RestMethod -Uri "http://localhost:8000/generate-plan" -Method Post -Body $body -ContentType "application/json"
```

**Sample abbreviated JSON response:** `plan_id` UUID string, `request_id` string, `qc` with `novelty_label` and `references[]`, `plan` with `protocol`, `materials`, `budget`, `validation`, `prompt_versions` map of `role_file -> sha256`.

**curl example:**

```powershell
curl.exe -s -X POST "http://localhost:8000/generate-plan" -H "Content-Type: application/json" -d "{\"hypothesis\":\"Cryopreservation of HeLa cells in DMEM supplemented with 10% trehalose yields a significantly higher post-thaw viability than equimolar sucrose, measured by trypan-blue exclusion 24 hours after thaw.\"}"
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

**Response:** same as `POST /generate-plan` (200). **404** with `code: validation_error` if the id is unknown (closed error set; no separate `not_found` code).

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

`POST /generate-plan` bodies (the four brief hypotheses, copy-paste as JSON `hypothesis` only):

**1 — CRP paper-based biosensor**

```json
{
  "hypothesis": "A paper-based electrochemical biosensor can detect C-reactive protein (CRP) in unprocessed whole blood within 10 minutes at the < 1 mg/L sensitivity needed for sepsis screening."
}
```

**2 — *Lactobacillus rhamnosus* GG / C57BL/6**

```json
{
  "hypothesis": "Daily oral gavage of Lactobacillus rhamnosus GG (ATCC 53103) to C57BL/6 mice for 14 days increases relative abundance of LGG in cecal contents by ≥ 1 log10 copies per gram compared with vehicle controls, measured by 16S rRNA qPCR."
}
```

**3 — Trehalose vs sucrose / HeLa**

```json
{
  "hypothesis": "Cryopreservation of HeLa cells in DMEM supplemented with 10% trehalose yields a significantly higher post-thaw viability than equimolar sucrose, measured by trypan-blue exclusion 24 hours after thaw."
}
```

**4 — *Sporomusa ovata* CO₂ fixation**

```json
{
  "hypothesis": "Sporomusa ovata grown on a graphite cathode at -400 mV vs SHE fixes CO2 into acetate at a Coulombic efficiency above 80%, sustained over a 7-day batch run."
}
```

**Example `POST /feedback` after a trehalose run** (replace `plan_id` with the `plan_id` from your `POST /generate-plan` response):

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
2. **Submit the trehalose hypothesis** with `POST /generate-plan` using the JSON from **Sample data** §3. You should receive `qc` (with novelty), `grounding_summary`, and a full `plan` (unless the novelty branch returns QC-only), plus `plan_id` and `prompt_versions`.
3. **Send feedback** with `POST /feedback` and the `plan_id` you received. Response includes `feedback_id` and `accepted: true`.
4. **Re-submit a related hypothesis** (e.g. same trehalose text with a minor tweak). Runtime Agent 2 should surface prior feedback as few-shot context to Agent 3; compare `plan.materials` or protocol notes to see the correction influence (see `tests` Step 45 for the automated expectation).

**Commands (abbreviated):**

```powershell
$h = '{"hypothesis":"Cryopreservation of HeLa cells in DMEM ..."}'
$r = Invoke-RestMethod "http://localhost:8000/generate-plan" -Method Post -Body $h -ContentType "application/json"
$pid = $r.plan_id
# ... POST /feedback with $pid, then generate-plan again
```

## Project structure

- `app/main.py` — FastAPI factory, lifespan (OpenAI, Tavily, DB).
- `app/api/` — routes (`generate_plan`, `feedback`, `plans`, `health`), `errors`, `middleware`, `deps`.
- `app/runtime/` — `orchestrator.py`, `novelty_gate.py`, `pipeline_state.py`.
- `app/agents/` — `literature_qc`, `feedback_relevance`, `experiment_planner`.
- `app/clients/` — OpenAI and Tavily abstractions (real + fakes for tests).
- `app/storage/` — async SQLite, `PlanRow` / `FeedbackRow`, repos.
- `app/schemas/` — Pydantic API and domain models, `SourceTier`, MIQE, errors.
- `app/prompts/` — `literature_qc.md`, `feedback_relevance.md`, `experiment_planner.md` + `loader.py`.
- `app/config/` — `settings.py`, `source_tiers.yaml`.
- `app/verification/` — citation and catalog resolvers, grounding.
- `tests/` — unit, API, e2e cassettes, injection tests, `test_readme.py`.
- `scripts/check.ps1` — canonical `pytest` + ruff + mypy gate.

## How it works (request flow)

A `POST /generate-plan` hits FastAPI, then the **runtime orchestrator** builds `pipeline_state`. **Runtime Agent 1** calls Tavily (domains from `source_tiers.yaml` Tier 1+2) and `gpt-4.1-mini` to produce `LiteratureQCResult`. The **novelty gate** either stops with QC only (`exact_match`) or continues. If it continues, **runtime Agent 2** reads `FeedbackRepo` for the tagged domain and passes few-shots to **runtime Agent 3** (`gpt-4.1` structured JSON). Resolvers verify DOIs/URLs and catalog SKUs; if grounding rules fail, the API returns `grounding_failed_refused`. On success, **PlansRepo** persists the `GeneratePlanResponse` with `schema_version` and `prompt_versions`. For a diagram reference, use `docs/architecture.svg` in the repo root.

## Trust & anti-hallucination guarantees

- **SourceTier** (`TIER_1_PEER_REVIEWED`, `TIER_2_PREPRINT_OR_COMMUNITY`, `TIER_3_GENERAL_WEB`, `TIER_0_FORBIDDEN`) is assigned in code from `app/config/source_tiers.yaml`, not by the LLM. Tier 0 is dropped; Tier 3 is not used for primary novelty/grounding.
- **Citation and catalog resolvers** (`app/verification/`) must mark items `verified` before they are treated as trustworthy; the global **50% unverified materials** rule triggers a refusal.
- **Role prompts** live under `app/prompts/`, are loaded by `loader.py`, and are hashed into `prompt_versions` — they are **never** concatenated with user text in the system channel.
- **Adversarial tests** under `tests/injection/` ensure injection strings do not become instructions or raise forbidden tiers.
- Reject fabricated outputs: if nothing verifies, the API refuses with `grounding_failed_refused` rather than inventing DOIs or SKUs.

## Observability & error contract

Each runtime agent call logs one **JSON** line via `structlog` with: `agent`, `model`, `prompt_hash` (role file sha256), `prompt_tokens`, `completion_tokens`, `latency_ms`, `verified_count`, `tier_0_drops`, `request_id` (and related orchestrator fields as implemented). The HTTP layer emits a per-request line with `event="http.request.complete"`. Find rows by `request_id` in logs and in persisted plan/feedback records.

**`ErrorCode` (8 only):** `validation_error` (422; includes unknown `plan_id` on GET), `tavily_unavailable` (503), `openai_unavailable` (503), `openai_rate_limited` (429; also per-IP rate limit on POST), `structured_output_invalid` (502), `grounding_failed_refused` (422), `cost_ceiling_exceeded` (402), `internal_error` (500).

**Example `ErrorResponse` body:**

```json
{
  "code": "grounding_failed_refused",
  "message": "plan refused: insufficient verifiable grounding",
  "details": {},
  "request_id": "01HMXYZ..."
}
```

## Development

- **Canonical check:** from repo root, `pwsh backend/scripts/check.ps1` (runs `pytest -q`, `ruff format .`, `ruff check .`, `mypy --strict .` from `backend/`).
- **Partial runs:** `uv run pytest -q`, `uv run ruff check .`, `uv run mypy --strict .`.
- **TDD:** red → green → refactor (see `.cursor/rules/tdd.mdc`); new behavior starts with a failing test in `tests/`.
- **Cassettes:** default suite is **offline**; to re-record against live APIs use `uv run pytest -m live --record-mode=once` with keys (explicit; never by default). Commit cassettes under `tests/cassettes/`.

## Troubleshooting

- **Missing `OPENAI_API_KEY` / `TAVILY_API_KEY`:** set env or `.env` in `backend/`; restart uvicorn.
- **OpenAI 429 / rate limit:** same as application `openai_rate_limited` — back off; POST rate limits also return 429 with that code.
- **Tavily empty / allowlist issues:** check `TAVILY_API_KEY` and `source_tiers` domains in logs.
- **SQLite file path (Windows):** default `./ai_scientist.db` under `backend/`; override `DATABASE_URL` if needed.
- **Port 8000 in use:** `uvicorn ... --port 8001`.
- **`structured_output_invalid`:** model returned non-conforming JSON for Agent 3 — inspect logs, prompts, and cassette drift.
- **`cost_ceiling_exceeded`:** increase `MAX_REQUEST_USD` carefully for long plans; see `settings.py`.
- **`grounding_failed_refused`:** check resolvers, Tier drops, and unverified material ratio.
- **Tests pass locally but CI fails cassettes:** re-record with the `live` marker on a dev machine, review diff, commit.

---

The AI Scientist (backend) | Spec: `04_The_AI_Scientist.docx.pdf` | Architecture: `docs/architecture.svg`
