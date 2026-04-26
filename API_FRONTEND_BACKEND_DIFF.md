# Frontend ↔ backend — remaining differences

**After** the two-step flow (`POST /literature-review` **SSE** + **`POST /experiment-plan`** with **`literature_review_id`**) and **GeneratePlanResponse**, these are the main gaps. Field-level truth: **`GET /openapi.json`**, and **[`docs/api_contract.md`](docs/api_contract.md)** (v1.1) + **[`FRONTEND_TODO.md`](FRONTEND_TODO.md)** for Flutter tasks.

---

## 1. Endpoint alignment

| Capability | Backend | Flutter (typical gap) |
|------------|---------|-------------------------|
| Literature | `POST /literature-review` — SSE, `data` with nested `event` + `data` | **Parse envelope**; read **`sources[].verified`**, **`unverified_similarity_suggestion`**, **`tier`**. |
| Experiment plan | `POST /experiment-plan` — **200 = `GeneratePlanResponse`** | Parse **envelope**; **`plan`** nested, not at root. |
| Saved plan | `GET /plans/{id}` | Same envelope; often not wired. |
| Feedback | `POST /feedback` | Optional; needs `plan_id` from a prior success. |
| Health / debug | `GET /health`, `GET /debug/tavily` | Optional. |

**Removed:** `POST /generate-plan` (replaced by the two-step flow).

---

## 2. `Source` / SSE vs Flutter `Source` DTO

| Topic | Backend (streamed `data.sources[]`) | Frontend |
|-------|--------------------------------------|----------|
| Trust | **`verified`**, **`unverified_similarity_suggestion`**, **`tier`** on every item | DTOs must add these; **do not** infer trust from `author` string alone. |
| Verification policy | A row is **verified** if the HTTP resolver succeeds **or** Tavily’s relevance **score for that work is &gt; 0.6** (see Agent 1 in `backend`). | UI may show “Tavily-backed” vs “HTTP-verified” later; for now `verified: true` is the gate. |
| Last-resort link | **At most one** unverified “similar” row when **no** verified references | Show clearly when **`unverified_similarity_suggestion: true`**. |
| `qc` on experiment-plan | **`LiteratureQCResult`**: `references` + optional **`similarity_suggestion`** (same idea as the SSE unverified path) | Map **`qc.references`** / **`qc.similarity_suggestion`** if you need parity with the literature step. |

---

## 3. `ExperimentPlan` shape vs `ExperimentPlanDto` (legacy mocks)

| Topic | Backend `plan` (when non-null) | Legacy / mock Flutter DTOs |
|-------|--------------------------------|----------------------------|
| Location | Under **`plan`** in **GeneratePlanResponse** | May assume `description` at **root** of HTTP body — **wrong**. |
| Field names | Often **`hypothesis`**, **`protocol`**, **`timeline`**, `materials` with **`reagent` / `vendor` / `sku`**, `budget` with `total_usd` | May use `time_plan`, `description` — **map or update DTOs** from **OpenAPI**. |

---

## 4. Error responses

| Topic | Backend `ErrorResponse` | Flutter `ApiErrorDto` (typical) |
|-------|------------------------|----------------------------------|
| Fields | `code`, `message`, **`details`**, **`request_id`** | Often only `code` + `message` — add **`request_id`** for support. |
| 422 on experiment-plan | Unknown **`literature_review_id`** or **query** mismatch | Handle explicitly (user must repeat literature step). |

---

## 5. What the frontend still should do

1. Implement streaming + **full** **`GeneratePlanResponse`** parsing against the real base URL.  
2. **Extend** `Source` and plan DTOs per **OpenAPI** (or generate from `/openapi.json`).  
3. Optional: `GET /plans`, `POST /feedback`, richer error display.

---

## 6. Backend-only (optional later)

- Crossref (or similar) for real authors/dates in SSE.  
- No separate “flat plan only” route unless product asks for it.

---

## 7. One-line summary

**Protocol and IDs are defined.** Remaining work is **Flutter**: **SSE envelope + new Source fields**, **envelope + nested `plan` + `qc`**, and **DTO/OpenAPI alignment**.
