# Backend contract: learning from user suggestions + plan bibliography references

**Audience:** Backend team (implementation handoff)  
**Related docs:** [`api_contract.md`](api_contract.md) (global conventions), [`be_experiment_plan_reviews_api.md`](be_experiment_plan_reviews_api.md) (mobile `Review` / `/reviews`), existing `GET /plans/{plan_id}` in `backend/app/api/plans.py`.  
**Status:** Specification — to be implemented or aligned with current `POST /feedback` + `FeedbackRepo` as the product chooses.

This document is a **frontend ↔ backend contract** covering two workstreams:

1. **Task 1 — Persist user suggestions** so they can be **retrieved and fed into later plan generation** (the AI “learns” from stored feedback).
2. **Task 2 — Include bibliography / provenance in the plan** so each **section, step, and material** can declare **which sources** (literature index or “agent prior learning”) informed that content.

---

## Global conventions (same as main API)

| Topic | Rule |
|-------|------|
| JSON keys | `snake_case` on the wire. |
| Datetimes | ISO 8601 with timezone, e.g. `2026-04-28T12:00:00Z`. |
| IDs | Opaque strings; `plan_id` must match the id returned when a plan is saved (see `POST /experiment-plan` / `GeneratePlanResponse`). |
| Auth | TBD; all endpoints are **per authenticated user** once auth ships. |
| Error body | `{ "code": "...", "message": "...", "request_id": "..."? }` (see `ApiError` in `api_contract.md`). |

---

# Task 1: Store user suggestions for lifelong learning

## Product requirements

- Every **suggestion** must be stored with:
  - **What kind of feedback it is** (field correction, anchored comment, section like/dislike, etc.).
  - **`plan_id`** — so the system can **load the plan** (e.g. `GET /plans/{plan_id}`) whenReasoning or auditing.
  - **`plan_name`** — a short, human-readable label for lists and UIs (not necessarily unique).
- **These records must be eligible inputs** when generating **any future** `POST /experiment-plan` run: retrieval / ranking / few-shot construction is **backend-internal**, but the **stored payload** must be rich enough to reconstruct context for the model (see payloads below).
- The mobile app may continue to send **`POST /reviews`** (see `be_experiment_plan_reviews_api.md`); the **backend** may either (a) treat **`/learning-suggestions` as the canonical store** and have the app post here, or (b) **ingest** `/reviews` and **normalize** into the same store. The JSON below is the **canonical shape the BE should persist and query**, regardless of which HTTP entry path you choose.

## Resource: `LearningSuggestion`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `suggestion_id` | string | yes (on read) | Server-generated stable id, e.g. `ls-…`. |
| `created_at` | string | yes | When the suggestion was stored. |
| `user_id` | string | when auth on | Owner of the suggestion. |
| `plan_id` | string | yes | Id of the experiment plan this feedback refers to. Use this with **`GET /plans/{plan_id}`** to load the plan snapshot. |
| `plan_name` | string | yes | Short display name (e.g. first line of description, or product-defined title). **Max length ~200** recommended. |
| `literature_review_id` | string \| null | no | Same id as the literature step for that session, if known. |
| `query` | string | yes | The user’s research question / hypothesis for that session (denormalised for retrieval and few-shots). |
| `suggestion_type` | string | yes | See [Suggestion types](#suggestion-types). |
| `payload` | object | yes | **Type-specific**; see [Payloads](#payloads-by-suggestion_type). |

### Suggestion types

| `suggestion_type` | Meaning |
|-------------------|--------|
| `field_correction` | User changed a single field (before → after) on the plan. |
| `anchored_comment` | User attached a free-text comment to a **substring** of a field. |
| `section_polarity` | User liked or disliked a **major section** of the plan (e.g. budget, steps). |
| `batch_corrections` | Optional: one stored event wrapping multiple field corrections (if product batches them). If unused, store multiple `field_correction` rows instead. |

### Payloads (by `suggestion_type`)

**`field_correction`**

```json
{
  "target": "step[step_1].name",
  "before": "Run pilot experiment",
  "after": "Run pilot assay with positive controls",
  "context_note": "optional free text from the user"
}
```

| Field | Type | Required |
|-------|------|----------|
| `target` | string | yes — same path vocabulary as the mobile `Review` contract (`plan.description`, `plan.budget.total`, `step[…]`, `material[…]`, etc.). |
| `before` | any | yes |
| `after` | any | yes |
| `context_note` | string | no |

**`anchored_comment`**

```json
{
  "target": "plan.description",
  "quote": "controlled T-cell expansion assay",
  "start": 2,
  "end": 36,
  "body": "Clarify the donor pool size in this sentence."
}
```

| Field | Type | Required |
|-------|------|----------|
| `target` | string | yes |
| `quote` | string | yes |
| `start` | int | yes |
| `end` | int | yes |
| `body` | string | yes |

**`section_polarity`**

```json
{
  "section": "steps",
  "polarity": "like"
}
```

| Field | Type | Required |
|-------|------|----------|
| `section` | string | yes — same values as the mobile `Review` payload: `totalTime`, `budget`, `timeline`, `steps`, `materials`, `risks` (Dart enum names on the wire). |
| `polarity` | string | yes — `like` or `dislike` |

**`batch_corrections` (optional)**

```json
{
  "items": [
    { "target": "plan.budget.total", "before": 1000, "after": 1200 }
  ]
}
```

## Endpoints (Task 1)

| Method | Path | Purpose |
|--------|------|--------|
| `POST` | `/learning-suggestions` | Persist one `LearningSuggestion` (or accept batched list if you prefer one round-trip; see **Batch variant** below). |
| `GET` | `/learning-suggestions` | List suggestions for the current user (paginated; **newest first** is typical for sync). **Used by the app or ops tools**; **plan generation** may call internal repos, not this GET, if you only index server-side. |

**Note:** If you keep **`POST /feedback`** (existing backend) for few-shots, either **migrate** its rows into this schema, **or** require **clients to send `POST /learning-suggestions`** (or `POST /reviews` that you map here) so **one** store feeds Agent 2 / experiment planner. The product goal is: **all learnable user signals** land in a **queryable** store with **`plan_id` + `plan_name` + `suggestion_type` + `payload`**.

### `POST /learning-suggestions` — request

```json
{
  "plan_id": "plan-a1b2c3d-4e5f-6789-0abc-def012345678",
  "plan_name": "Cold exposure — pilot and optimisation",
  "literature_review_id": "lr-98ab76cd-0011-4455-6677-8899aabbccdd",
  "query": "Does cold exposure improve insulin sensitivity in healthy adults?",
  "suggestion_type": "field_correction",
  "payload": {
    "target": "step[step_1].name",
    "before": "Run pilot experiment",
    "after": "Run pilot assay with positive controls"
  }
}
```

**Response (success, `200 OK`):**

```json
{
  "suggestion": {
    "suggestion_id": "ls-7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6",
    "created_at": "2026-04-28T14:22:00Z",
    "user_id": "user-uuid",
    "plan_id": "plan-a1b2c3d-4e5f-6789-0abc-def012345678",
    "plan_name": "Cold exposure — pilot and optimisation",
    "literature_review_id": "lr-98ab76cd-0011-4455-6677-8899aabbccdd",
    "query": "Does cold exposure improve insulin sensitivity in healthy adults?",
    "suggestion_type": "field_correction",
    "payload": {
      "target": "step[step_1].name",
      "before": "Run pilot experiment",
      "after": "Run pilot assay with positive controls"
    }
  }
}
```

### `GET /learning-suggestions` — response (paginated)

```json
{
  "suggestions": [ ],
  "next_cursor": null
}
```

### Batch variant (optional)

If the product prefers a single request for many atomic suggestions:

- **`POST /learning-suggestions/batch`**
- **Body:** `{ "items": [ { … same fields as single POST, without suggestion_id } ] }`
- **Response:** `{ "suggestions": [ … ], "rejected": [ ] }`

## Backend use in later plans (non-HTTP, implementation requirement)

- **When** handling `POST /experiment-plan`, the orchestrator (or a dedicated retrieval step) **MUST** be able to load **relevant** `LearningSuggestion` rows (by user, by domain, by semantic similarity to `query`, etc.) and convert them to **few-shot** or **context** for the planner — consistent with the existing pattern that uses `FeedbackRepo` + `FeedbackRelevanceAgent` in the Python backend.
- The **contract** for the **HTTP API** is the stored record above; the **retrieval & prompt assembly** is **internal** but must **use this store** (not only ad-hoc `POST /feedback` text) if product requires full parity with mobile.

---

# Task 2: Bibliography / provenance on the plan

## Product requirements

- The **`ExperimentPlan`** returned from **`POST /experiment-plan`** (and from **`GET /plans/{plan_id}`**) must allow the UI to show **which literature references** (from the same session’s literature list) or **“agent prior learning”** were used to justify:
  - **Section-level** blocks (e.g. “Steps” section header, “Materials” section header), and
  - **Each step** in the timeline, and
  - **Each material** line item.

- **“Self” / prior learning:** a reference that does **not** point to a paper index but indicates **knowledge from a previous model session or internal memory**. On the wire this is the same as the product term **“previous learning”** (see `PlanSourceRef` below).

## Type: `PlanSourceRef` (discriminated by `kind`)

| `kind` | Additional fields | Semantics |
|--------|-------------------|-----------|
| `literature` | `reference_index` (int, **1-based**) | Index into the **`sources`** array** from `POST /literature-review` for the **same** `query` / `literature_review_id` session. |
| `previous_learning` | (none) | **“Self”** / agent’s prior learning — not a bibliography row. UI shows a distinct badge (e.g. light-bulb). Product may label this **“Self”** in the app. |

**Wire examples:**

```json
{ "kind": "literature", "reference_index": 2 }
```

```json
{ "kind": "previous_learning" }
```

(If you need a string alias, `"self"` is **not** the canonical `kind` in the current FE; prefer `previous_learning` and map **“Self”** in copy only.)

## Where references attach on `ExperimentPlan`

| Location | JSON field | Applies to |
|----------|------------|------------|
| Steps **section** (header / block) | `steps_section_source_refs` | array of `PlanSourceRef` |
| Materials **section** (header / block) | `materials_section_source_refs` | array of `PlanSourceRef` |
| Each **step** (inside `time_plan.steps[]`) | `source_refs` | array of `PlanSourceRef` |
| Each **material** (inside `budget.materials[]`) | `source_refs` | array of `PlanSourceRef` |

All of these are **optional**; use empty arrays or omit when nothing applies.

## Example: `ExperimentPlan` fragment with section + step + material refs

```json
{
  "description": "A pilot-first expansion assay with triplicate readouts…",
  "steps_section_source_refs": [
    { "kind": "literature", "reference_index": 1 }
  ],
  "materials_section_source_refs": [
    { "kind": "previous_learning" }
  ],
  "budget": {
    "total": 1200.0,
    "currency": "USD",
    "materials": [
      {
        "title": "Recombinant IL-2",
        "catalog_number": "IL2-200",
        "description": "For expansion culture.",
        "amount": 1,
        "price": 400.0,
        "source_refs": [
          { "kind": "literature", "reference_index": 3 }
        ]
      }
    ]
  },
  "time_plan": {
    "total_duration_seconds": 1728000,
    "steps": [
      {
        "number": 1,
        "duration_seconds": 86400,
        "name": "Procure reagents",
        "description": "Order cytokines and medium per protocol.",
        "milestone": null,
        "source_refs": [
          { "kind": "literature", "reference_index": 1 },
          { "kind": "previous_learning" }
        ]
      }
    ]
  }
}
```

## BE responsibilities for Task 2

- **Emit** `PlanSourceRef` arrays when generating a plan: **grounding** and **citation** logic should set `literature` where a **specific paper** from the current review drove text; set **`previous_learning`** where the model relied on **non-bibliography** knowledge the product treats as “self”.
- **Persist** the same `ExperimentPlan` JSON (including `source_refs` fields) in **`GET /plans/{plan_id}`** so the app can re-open a saved plan with badges intact.
- **Validation:** `reference_index` must be **in range** for the session’s literature `sources` list when `kind` is `literature`; the FE may **skip** invalid refs defensively, but the BE should avoid emitting out-of-range indices.

## Alignment with the Flutter app

- The app already models **`PlanSourceRef`** as **literature** (index) vs **previous learning** (see `frontend/lib/models/plan_source_ref.dart`). The **`kind` strings and shape above must match** the main [`api_contract.md`](api_contract.md) §4.2 / §4.9 so DTOs stay stable.

---

## Change log

| Version | Date | Author | Notes |
|---------|------|--------|-------|
| 1.0 | 2026-04-28 | — | First draft: learning suggestions store + plan `PlanSourceRef` contract. |
