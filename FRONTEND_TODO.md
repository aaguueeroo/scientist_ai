# Frontend — sync with backend API

This repo’s **Flutter** app under `frontend/` should match the **FastAPI** backend in `backend/`. The single source of truth for field names and types is **`GET {BASE_URL}/openapi.json`** (also **`/docs`** in development).

**Docs in this monorepo**

| Doc | Use |
|-----|-----|
| [`docs/api_contract.md`](docs/api_contract.md) | Human-readable contract (v1.1); keep aligned with OpenAPI. |
| [`API_FRONTEND_BACKEND_DIFF.md`](API_FRONTEND_BACKEND_DIFF.md) | Remaining product gaps vs the server. |
| [`backend/README.md`](backend/README.md) | How to run the API, sample curls, high-level behavior. |

---

## 1. `POST /literature-review` (SSE)

- **Request body:** `{"query": string, "request_id": string}` (same `query` you will send to experiment-plan; max **4000** chars on the server for `query`).
- **Response:** `Content-Type: text/event-stream`. Each chunk is a line `data: ` + **one JSON object** (then blank line). The object looks like: `{"event": "review_update" \| "error", "data": { ... } }`.
- **Final `review_update`:** `data.is_final === true`, and **`data.literature_review_id`** (required for the next step). Correlation: also read header **`X-Request-ID`**.

**`data.sources[]` (each item — mirror OpenAPI `LiteratureReviewSseSource`)**

| Field | Meaning for UI |
|-------|----------------|
| `author` | Distinguish “Verified source (tier-assigned)” vs “Unverified (similarity suggestion)”. |
| `title`, `abstract`, `date_of_publication`, `doi` | Display; `abstract` may start with `[Unverified — similar content only, not HTTP-verified]`. |
| **`verified`** | `true` for HTTP-resolver success **or** Tavily relevance **score &gt; 0.6** (backend treats strong Tavily as verified). |
| **`unverified_similarity_suggestion`** | `true` only for the optional last-resort similar row when there were **no** verified rows. |
| **`tier`** | e.g. `tier_1_peer_reviewed`, `tier_3_general_web` — for badges / trust UI. |

**Error:** `event === "error"` with `data.code`, `data.message` (and server may use `ErrorResponse` with `request_id` elsewhere).

**DTO work:** Add/adjust a `Source` (or server-named) DTO to include **`verified`**, **`unverified_similarity_suggestion`**, **`tier`**; do not assume the stream matches old mocks that omitted these fields.

---

## 2. `POST /experiment-plan` (JSON)

- **Request body (both required):** `{ "query": string, "literature_review_id": string }`  
  - `query`: **10–2000** chars on the server, must **match** the stored literature text (trimmed).  
  - `literature_review_id`: from the **final** literature SSE. Wrong id or query → **422**.

- **Response (200):** **`GeneratePlanResponse`**, **not** a top-level `ExperimentPlan` DTO. Parse at least:

| Field | Notes |
|-------|--------|
| `plan_id` | `null` if novelty gate returns QC only (`exact_match`). |
| `request_id` | This HTTP call’s id (ties to logs). |
| **`qc`** | **LiteratureQCResult** — `references` (max 3), optional **`similarity_suggestion`**, `novelty`, `confidence`, `tier_0_drops`. References may be “verified” via resolver or strong Tavily score. |
| **`plan`** | **ExperimentPlan** or `null` — the structured plan is **here**, not at the root. |
| `grounding_summary` | Counts for verification / tier-0 drops. |
| `prompt_versions` | Optional debug: prompt file hashes. |

- **Map** the nested `plan` to your existing UI models (`hypothesis`, `protocol`, `materials`, …) or adopt server names from **OpenAPI**.

---

## 3. Other endpoints (optional for v1)

| Method | Use |
|--------|-----|
| `GET /plans/{plan_id}` | Same envelope as a successful experiment-plan. |
| `POST /feedback` | After a run with a real `plan_id`; see `backend/README.md` / OpenAPI. |
| `GET /health` | Liveness. |

**Errors:** Bodies are **`ErrorResponse`**: `code`, `message`, `details?`, `request_id`. Surface **`request_id`** in support and errors.

---

## 4. `GET /debug/tavily` (not for production UI)

- Raw Tavily JSON; **`restrict_domains=false`** = open web. **Do not** expect this to mirror the internal literature pipeline (the server may add an open-web step that this route does not).

---

## 5. Checklist for integration

1. [ ] **SSE client** — parse `data: {"event", "data"}`; read `literature_review_id` from final `data`.
2. [ ] **Source DTO** — add `verified`, `unverified_similarity_suggestion`, `tier`, and unverified-abstract prefix handling.
3. [ ] **Experiment plan client** — parse **GeneratePlanResponse**; read **`plan`**, **`qc`**, not a flat plan at root.
4. [ ] **Store & resend** `literature_review_id` + `query` for `/experiment-plan`.
5. [ ] **Errors** — show or log `request_id` from `ErrorResponse`.

---

*Removed from older versions of this file: references to a non-existent `FRONTEND_JSON_API_CONTRACT.md` (use `docs/api_contract.md` + OpenAPI), and the obsolete “optional `literature_review_id`” / flat plan response contract.*
