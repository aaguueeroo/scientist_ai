# Scientist AI — Frontend ↔ Backend API Contract

**Version:** 1.1 (first flow + reviewer)
**Status:** Active — implemented on the FE against a mock backend client.
**Scope:** This document defines every HTTP endpoint, request body, response body, SSE event, error code, data type, and field convention that the FE expects from the BE for the **first flow**: a user submits a research question and receives a literature review followed by an experiment plan.

---

## Table of contents

1. [Overview of the flow](#1-overview-of-the-flow)
2. [Global conventions](#2-global-conventions)
3. [Endpoints](#3-endpoints)
   - 3.1 [`POST /literature-review`](#31-post-literature-review)
   - 3.2 [`POST /experiment-plan`](#32-post-experiment-plan)
   - 3.3 [`POST /reviews`](#33-post-reviews)
   - 3.4 [`GET /reviews`](#34-get-reviews)
4. [Object schemas](#4-object-schemas)
   - 4.1 [`Source`](#41-source)
   - 4.2 [`ExperimentPlan`](#42-experimentplan)
   - 4.3 [`Budget`](#43-budget)
   - 4.4 [`Material`](#44-material)
   - 4.5 [`TimePlan`](#45-timeplan)
   - 4.6 [`Step`](#46-step)
   - 4.7 [`ApiError`](#47-apierror)
   - 4.8 [`Review`](#48-review)
5. [SSE events](#5-sse-events)
   - 5.1 [`review_update`](#51-review_update)
   - 5.2 [`error`](#52-error)
6. [Error model](#6-error-model)
7. [Acceptance test vectors](#7-acceptance-test-vectors)
8. [Reference fixtures](#8-reference-fixtures)
9. [Change log](#9-change-log)

---

## 1. Overview of the flow

```text
                   ┌───────────────────────────┐
       user query  │                           │   POST /literature-review
   ───────────────▶│         FRONTEND          │──────────────────────────┐
                   │  (Flutter / Provider /    │                          │
                   │  ScientistRepository)     │                          ▼
                   │                           │              ┌────────────────────┐
                   │                           │◀─── SSE ─────│      BACKEND       │
                   │                           │  review_update events     ▲
                   │                           │  + final + error          │
                   │                           │                           │
                   │                           │  POST /experiment-plan    │
                   │                           │──────────────────────────▶│
                   │                           │                           │
                   │                           │◀──── JSON ── 200 OK ──────│
                   │                           │      (ExperimentPlan)
                   └───────────────────────────┘
```

1. User submits a free-text research question on the Home screen.
2. FE calls **`POST /literature-review`** and consumes the SSE stream. Each `review_update` event is rendered as a progressive list of sources. Stream ends on `is_final: true` or an `error` event.
3. After reviewing the sources, the user clicks "Generate experiment plan".
4. FE calls **`POST /experiment-plan`** and renders the returned `ExperimentPlan`.

There is no streaming for `/experiment-plan` in v1.

---

## 2. Global conventions

| Topic | Rule |
|---|---|
| Base URL | TBD. Configured FE-side; injected into the HTTP client. |
| Auth | TBD. Will be added in a future version (header-based). |
| Request `Content-Type` | `application/json; charset=utf-8` |
| Response `Content-Type` (JSON endpoints) | `application/json; charset=utf-8` |
| Response `Content-Type` (streaming endpoints) | `text/event-stream; charset=utf-8` |
| JSON key casing | `snake_case` for ALL keys, request and response, top-level and nested. |
| Dates | ISO 8601 calendar date `YYYY-MM-DD` (no time component). |
| Datetimes (future use) | ISO 8601 with timezone, e.g. `2026-04-25T22:30:00Z`. |
| Durations | **Integer seconds** as a JSON number. No ISO 8601 duration strings. |
| Money | JSON number (decimal). Always paired with an explicit `currency`. |
| Currency | ISO 4217 alpha codes, uppercase: `"USD"`, `"EUR"`, ... |
| Booleans | `true`/`false` (never `0`/`1`, never `"true"`/`"false"`). |
| Optional fields | Use JSON `null` rather than omitting the key. |
| Unknown fields | The FE ignores them; the BE SHOULD ignore unknown request fields. |
| Character encoding | UTF-8. |
| HTTP versions | HTTP/1.1 minimum (SSE compatibility). HTTP/2 acceptable. |

---

## 3. Endpoints

### 3.1 `POST /literature-review`

Streams a literature review for the user's question. Each event delivered over SSE is a **full cumulative snapshot** of the review state so far.

#### Request

- **Method:** `POST`
- **Path:** `/literature-review`
- **Headers:**
  - `Content-Type: application/json; charset=utf-8`
  - `Accept: text/event-stream`
- **Body:** see below.

##### Request body

```json
{
  "query": "Does cold exposure improve insulin sensitivity in healthy adults?",
  "request_id": "req_1745619021123456"
}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `query` | string | yes | The user's research question. Trimmed by the FE; non-empty. Max length: 4000 chars (FE-side cap; BE may enforce its own). |
| `request_id` | string | yes | FE-generated correlation id used in logs and for cancellation. Format: opaque ASCII string. |

#### Response

- **Status:** `200 OK` (then SSE stream).
- **Content-Type:** `text/event-stream; charset=utf-8`
- **Body:** A sequence of SSE events. See [SSE events](#5-sse-events).

The BE MUST close the stream after either:
- a `review_update` event with `"is_final": true`, **or**
- an `error` event.

##### Sample stream — happy path

```text
event: review_update
data: {"is_final":false,"does_similar_work_exist":true,"expected_total_sources":8,"sources":[{"author":"A. Kim et al.","title":"Optimized cytokine concentrations for T-cell expansion","date_of_publication":"2022-07-12","abstract":"This study evaluates ...","doi":"10.1126/sciimmunol.22.7812"}]}

event: review_update
data: {"is_final":false,"does_similar_work_exist":true,"expected_total_sources":8,"sources":[{...source 1...},{...source 2...}]}

...

event: review_update
data: {"is_final":true,"does_similar_work_exist":true,"expected_total_sources":8,"sources":[{...source 1...},{...},{...source 5...}]}
```

##### Sample stream — empty results

```text
event: review_update
data: {"is_final":true,"does_similar_work_exist":false,"expected_total_sources":0,"sources":[]}
```

##### Sample stream — error

```text
event: error
data: {"code":"internal_error","message":"Progressive literature lookup failed."}
```

#### Cancellation

The FE cancels by closing the HTTP connection. The BE SHOULD treat connection close as cancellation and stop work.

#### Failure modes

| Scenario | BE response |
|---|---|
| Validation error (empty/oversized query, etc.) | `400 Bad Request` with [`ApiError`](#47-apierror) JSON body OR a `200 OK` followed immediately by an `error` SSE event. FE treats both equivalently. |
| Auth failure (future) | `401 Unauthorized` with `ApiError` body. |
| Rate-limited | `429 Too Many Requests` with `ApiError` body. |
| Server failure mid-stream | `event: error` over the open SSE stream, then close. |

---

### 3.2 `POST /experiment-plan`

Generates a full experiment plan (description + budget + timeline) for a query. Synchronous JSON request/response.

#### Request

- **Method:** `POST`
- **Path:** `/experiment-plan`
- **Headers:**
  - `Content-Type: application/json; charset=utf-8`
  - `Accept: application/json`
- **Body:** see below.

##### Request body

```json
{
  "query": "Does cold exposure improve insulin sensitivity in healthy adults?",
  "literature_review_id": null
}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `query` | string | yes | Same query that was used for the literature review. Trimmed, non-empty. |
| `literature_review_id` | string \| null | no | Optional id linking this plan to a previously streamed literature review. May be `null` until the BE assigns and returns review ids. |

#### Response

- **Status (success):** `200 OK`
- **Content-Type:** `application/json; charset=utf-8`
- **Body:** an [`ExperimentPlan`](#42-experimentplan) object.

##### Sample response

```json
{
  "description": "A controlled T-cell expansion assay evaluating cytokine concentration ranges in serum-free medium, with pilot validation and dose-response optimization across triplicate conditions.",
  "budget": {
    "total": 5870.50,
    "currency": "USD",
    "materials": [
      {
        "title": "Recombinant Cytokine Kit",
        "catalog_number": "CYT-4902",
        "description": "Cytokine blend for controlled expansion.",
        "amount": 2,
        "price": 480.00
      },
      {
        "title": "Serum-Free Medium",
        "catalog_number": "SFM-1000",
        "description": "Defined medium for immune cell assays.",
        "amount": 6,
        "price": 145.00
      },
      {
        "title": "Assay Plates 96-well",
        "catalog_number": "APL-96-300",
        "description": "Sterile flat-bottom assay plates.",
        "amount": 10,
        "price": 23.50
      },
      {
        "title": "Flow Cytometry Antibody Panel",
        "catalog_number": "FCP-8CLR",
        "description": "Eight-color validation panel.",
        "amount": 3,
        "price": 620.00
      },
      {
        "title": "Pipette Tip Rack",
        "catalog_number": "PTR-200",
        "description": "Filtered, sterile universal tips.",
        "amount": 12,
        "price": 19.00
      },
      {
        "title": "Control Compound Set",
        "catalog_number": "CCS-042",
        "description": "Positive and negative assay controls.",
        "amount": 1,
        "price": 1720.00
      }
    ]
  },
  "time_plan": {
    "total_duration_seconds": 1058400,
    "steps": [
      {
        "number": 1,
        "duration_seconds": 172800,
        "name": "Finalize protocol scope",
        "description": "Review query constraints, acceptance criteria, and define assay success metrics with the requesting scientist.",
        "milestone": "Protocol approved"
      },
      {
        "number": 2,
        "duration_seconds": 216000,
        "name": "Procure materials",
        "description": "Order all consumables and reagents, verify catalog substitutions, and confirm delivery windows with suppliers.",
        "milestone": null
      },
      {
        "number": 3,
        "duration_seconds": 259200,
        "name": "Run pilot experiment",
        "description": "Execute pilot assay with baseline concentrations and collect first-pass quality and viability readouts.",
        "milestone": "Pilot data collected"
      },
      {
        "number": 4,
        "duration_seconds": 194400,
        "name": "Optimize concentration ranges",
        "description": "Tune dosage windows based on pilot results and run confirmation repeats for shortlisted conditions.",
        "milestone": null
      },
      {
        "number": 5,
        "duration_seconds": 216000,
        "name": "Prepare lab-ready report",
        "description": "Compile final timeline, material usage, and validation notes into a proposal package for lab execution.",
        "milestone": "Report delivered"
      }
    ]
  }
}
```

#### Failure modes

| Scenario | BE response |
|---|---|
| Validation error | `400 Bad Request` + [`ApiError`](#47-apierror) body. |
| Auth failure (future) | `401 Unauthorized` + `ApiError` body. |
| Referenced `literature_review_id` not found | `404 Not Found` + `ApiError` body, `code: "not_found"`. |
| Rate-limited | `429 Too Many Requests` + `ApiError` body. |
| Internal failure | `500 Internal Server Error` + `ApiError` body. |
| Upstream timeout | `504 Gateway Timeout` + `ApiError` body, `code: "timeout"`. |

---

### 3.3 `POST /reviews`

Persists a single user-emitted review event (a correction, a comment, or a like/dislike). The FE submits one request per atomic feedback the user generates. Synchronous JSON request/response.

#### Request

- **Method:** `POST`
- **Path:** `/reviews`
- **Headers:**
  - `Content-Type: application/json; charset=utf-8`
  - `Accept: application/json`
- **Body:** a [`Review`](#48-review) object. The FE generates `id` and `created_at`; the BE MAY override them.

##### Sample request — correction

```json
{
  "id": "review_lq2x8aab_1_pn8z",
  "created_at": "2026-04-26T22:10:00Z",
  "conversation_id": "Does cold exposure improve insulin sensitivity in healthy adults?",
  "query": "Does cold exposure improve insulin sensitivity in healthy adults?",
  "original_plan": { /* ... full ExperimentPlan ... */ },
  "kind": "correction",
  "payload": {
    "target": "step[step_3].name",
    "before": "Run pilot experiment",
    "after": "Run pilot assay with positive controls"
  }
}
```

##### Sample request — comment

```json
{
  "id": "review_lq2x8aac_2_q3sa",
  "created_at": "2026-04-26T22:11:00Z",
  "conversation_id": "Does cold exposure improve insulin sensitivity in healthy adults?",
  "query": "Does cold exposure improve insulin sensitivity in healthy adults?",
  "original_plan": { /* ... full ExperimentPlan ... */ },
  "kind": "comment",
  "payload": {
    "target": "plan.description",
    "quote": "controlled T-cell expansion assay",
    "start": 2,
    "end": 36,
    "body": "Clarify the donor pool size in this sentence."
  }
}
```

##### Sample request — feedback

```json
{
  "id": "review_lq2x8aad_3_r4tb",
  "created_at": "2026-04-26T22:12:00Z",
  "conversation_id": "Does cold exposure improve insulin sensitivity in healthy adults?",
  "query": "Does cold exposure improve insulin sensitivity in healthy adults?",
  "original_plan": { /* ... full ExperimentPlan ... */ },
  "kind": "feedback",
  "payload": {
    "section": "steps",
    "polarity": "like"
  }
}
```

#### Response

- **Status (success):** `200 OK`
- **Content-Type:** `application/json; charset=utf-8`
- **Body:** the stored [`Review`](#48-review) object (echoes the request, with any BE-side normalisation).

#### Failure modes

| Scenario | BE response |
|---|---|
| Validation error (malformed payload, unknown `kind`, etc.) | `400 Bad Request` + [`ApiError`](#47-apierror) body, `code: "invalid_query"`. |
| Auth failure (future) | `401 Unauthorized` + `ApiError` body. |
| Rate-limited | `429 Too Many Requests` + `ApiError` body. |
| Internal failure | `500 Internal Server Error` + `ApiError` body. |

---

### 3.4 `GET /reviews`

Returns every review the current user has ever submitted, across all conversations. Used by the Reviewer screen on app startup.

#### Request

- **Method:** `GET`
- **Path:** `/reviews`
- **Headers:**
  - `Accept: application/json`

#### Response

- **Status (success):** `200 OK`
- **Content-Type:** `application/json; charset=utf-8`
- **Body:**

```json
{
  "reviews": [
    { /* Review */ },
    { /* Review */ }
  ]
}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `reviews` | array of [`Review`](#48-review) | yes | Ordered by `created_at` descending (most recent first). May be empty. |

#### Failure modes

| Scenario | BE response |
|---|---|
| Auth failure (future) | `401 Unauthorized` + `ApiError` body. |
| Rate-limited | `429 Too Many Requests` + `ApiError` body. |
| Internal failure | `500 Internal Server Error` + `ApiError` body. |

---

## 4. Object schemas

All objects below are returned as JSON. Field tables are authoritative; sample JSON in the endpoint sections illustrates them.

### 4.1 `Source`

A single literature reference returned inside a `review_update` event.

| Field | Type | Required | Notes |
|---|---|---|---|
| `author` | string | yes | E.g. `"A. Kim et al."`. Free-form, may include "et al." |
| `title` | string | yes | Full paper title. |
| `date_of_publication` | string | yes | ISO 8601 date `YYYY-MM-DD`. |
| `abstract` | string | yes | Plain text. May contain newlines. |
| `doi` | string | yes | Bare DOI (e.g. `"10.1126/sciimmunol.22.7812"`), no `https://doi.org/` prefix. |

### 4.2 `ExperimentPlan`

Top-level response body for `POST /experiment-plan`.

| Field | Type | Required | Notes |
|---|---|---|---|
| `description` | string | yes | Human-readable summary of the plan. |
| `budget` | [`Budget`](#43-budget) | yes |  |
| `time_plan` | [`TimePlan`](#45-timeplan) | yes |  |
| `steps_section_source_refs` | array of [`PlanSourceRef`](#49-plansourceref) | no | Source citations for the Steps section header. Omit or use `[]` when none. |
| `materials_section_source_refs` | array of [`PlanSourceRef`](#49-plansourceref) | no | Source citations for the Materials section header. Omit or use `[]` when none. |

### 4.3 `Budget`

| Field | Type | Required | Notes |
|---|---|---|---|
| `total` | number | yes | Aggregate cost. Should equal `sum(materials[].amount * materials[].price)`; FE does not recompute. |
| `currency` | string | yes | ISO 4217 (e.g. `"USD"`). |
| `materials` | array of [`Material`](#44-material) | yes | May be empty. Order is preserved by FE display. |

### 4.4 `Material`

| Field | Type | Required | Notes |
|---|---|---|---|
| `title` | string | yes | Product / reagent name. |
| `catalog_number` | string | yes | Vendor catalog number. May be empty string `""` when unknown (NOT `null`). |
| `description` | string | yes | Free-form description. |
| `amount` | int | yes | Number of units to purchase. Must be ≥ 0. |
| `price` | number | yes | **Unit** price expressed in `budget.currency`. |
| `source_refs` | array of [`PlanSourceRef`](#49-plansourceref) | no | Source citations for this material. Omit or use `[]` when none. |

### 4.5 `TimePlan`

| Field | Type | Required | Notes |
|---|---|---|---|
| `total_duration_seconds` | int | yes | Should equal `sum(steps[].duration_seconds)`. |
| `steps` | array of [`Step`](#46-step) | yes | Ordered. May be empty (FE shows empty timeline). |

### 4.6 `Step`

| Field | Type | Required | Notes |
|---|---|---|---|
| `number` | int | yes | 1-indexed step number; must match array order. |
| `duration_seconds` | int | yes | Duration of this step in seconds. ≥ 0. |
| `name` | string | yes | Short label (e.g. `"Procure materials"`). |
| `description` | string | yes | Free-form details. |
| `milestone` | string \| null | no | Non-null marks this step as a milestone in the timeline UI. The string is the milestone label (e.g. `"Pilot data collected"`). Use `null` (not omission) when not a milestone. |
| `source_refs` | array of [`PlanSourceRef`](#49-plansourceref) | no | Source citations for this step. Omit or use `[]` when none. |

### 4.9 `PlanSourceRef`

A citation linking part of the experiment plan to a source.

| Field | Type | Required | Notes |
|---|---|---|---|
| `kind` | string | yes | One of `"literature"` or `"previous_learning"`. |
| `reference_index` | int | when `kind == "literature"` | 1-based index into the `sources` array returned by `POST /literature-review` for the same query. FE validates the index against the loaded review; out-of-range refs are silently skipped. |

**Example — literature ref:** `{ "kind": "literature", "reference_index": 2 }`

**Example — previous learning:** `{ "kind": "previous_learning" }`

Literature badges display the `reference_index` numeral in a circle; previous-learning badges display a light-bulb icon. Both are tappable and scroll the plan to the References panel at the bottom, where numbered literature entries (matching the badges) and a single "previous learning" explanation row are shown.

### 4.7 `ApiError`

Common error body. Used as the response body of HTTP `4xx`/`5xx` responses and as the `data:` payload of an SSE `error` event.

| Field | Type | Required | Notes |
|---|---|---|---|
| `code` | string | yes | Machine-readable error code. See [Error model](#6-error-model) for the vocabulary. |
| `message` | string | yes | Human-readable description. May be surfaced in logs; FE shows a generic friendly message in the UI. |

### 4.8 `Review`

A single piece of feedback the user gave the AI on a generated experiment plan. The FE persists each accepted correction, each comment, and each like/dislike as one `Review`.

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | string | yes | Stable id. FE generates a local id; BE MAY replace on persist. |
| `created_at` | string | yes | ISO 8601 datetime with timezone (e.g. `2026-04-26T22:10:00Z`). |
| `conversation_id` | string | yes | Identifies the source conversation. In v1 the FE uses the original query string as the conversation id (a real id will replace this once `GET /conversations` exists). |
| `query` | string | yes | The original research question for that conversation. Denormalised so the Reviewer screen can show the conversation label even if the conversation list is unavailable. |
| `original_plan` | [`ExperimentPlan`](#42-experimentplan) | yes | Full snapshot of the plan **before** any user corrections, captured at the moment the review was created. The Reviewer screen renders this snapshot when the user clicks the review. |
| `kind` | string | yes | One of `"correction"`, `"comment"`, `"feedback"`. Determines the shape of `payload`. |
| `payload` | object | yes | Kind-specific. See subsections below. |

#### 4.8.1 `payload` for `kind: "correction"`

| Field | Type | Required | Notes |
|---|---|---|---|
| `target` | string | yes | Address of the field that was changed. Format matches the FE's `ChangeTarget.toString()`: `"plan.description"`, `"plan.budget.total"`, `"plan.timePlan.totalDuration"`, `"step[<step_id>].<field>"` where `<field>` ∈ `{name, description, duration, milestone}`, `"material[<material_id>].<field>"` where `<field>` ∈ `{title, catalogNumber, description, amount, price}`. |
| `before` | any | yes | The previous value (string for text fields, number for `total`, integer seconds for `duration`/`totalDuration`, etc.). |
| `after` | any | yes | The new value (same type as `before`). |

#### 4.8.2 `payload` for `kind: "comment"`

| Field | Type | Required | Notes |
|---|---|---|---|
| `target` | string | yes | Same address vocabulary as for corrections. |
| `quote` | string | yes | The substring of the target text the comment is anchored to. |
| `start` | int | yes | Inclusive start offset of `quote` inside the target text at the time the comment was created. |
| `end` | int | yes | Exclusive end offset; `text.substring(start, end) == quote`. |
| `body` | string | yes | The comment text. |

#### 4.8.3 `payload` for `kind: "feedback"`

| Field | Type | Required | Notes |
|---|---|---|---|
| `section` | string | yes | One of `"totalTime"`, `"budget"`, `"timeline"`, `"steps"`, `"materials"`. Identifies the plan section that received the like/dislike. |
| `polarity` | string | yes | One of `"like"`, `"dislike"`. |

---

## 5. SSE events

The streaming endpoint `POST /literature-review` emits Server-Sent Events. Two event names are defined in v1.

### 5.1 `review_update`

A full cumulative snapshot of the literature review state. The FE reflects the latest snapshot and discards earlier ones.

```text
event: review_update
data: <JSON>
```

`<JSON>` schema:

| Field | Type | Required | Notes |
|---|---|---|---|
| `is_final` | bool | yes | `true` only on the LAST `review_update`. After this event, BE closes the stream. |
| `does_similar_work_exist` | bool | yes | If `false`, FE displays the empty-results UI. |
| `expected_total_sources` | int | yes | Total sources the BE expects to find for this query. May be larger than `sources.length` while streaming; equals `sources.length` for the final event when results were complete. |
| `sources` | array of [`Source`](#41-source) | yes | **Cumulative**, not a delta. Each event repeats all previously delivered sources plus any new ones. May be empty. |

### 5.2 `error`

Terminal event emitted when the BE cannot complete the request. After this event, the BE closes the stream.

```text
event: error
data: <ApiError JSON>
```

`<JSON>` is an [`ApiError`](#47-apierror) object.

---

## 6. Error model

### 6.1 Where errors appear

- HTTP `4xx`/`5xx` responses on any endpoint → response body is an [`ApiError`](#47-apierror).
- SSE `error` event on `/literature-review` → `data:` payload is an [`ApiError`](#47-apierror).

### 6.2 `code` vocabulary

The FE does not switch on `code` for UX in v1 (it shows a generic message), but the BE SHOULD use one of the values below so future FE versions can branch on them.

| Code | When to use | Recommended HTTP status |
|---|---|---|
| `invalid_query` | Query failed validation (empty, oversized, unsupported language, etc.). | `400` |
| `unauthorized` | Missing / invalid auth credentials (future). | `401` |
| `forbidden` | Authenticated but not allowed. | `403` |
| `not_found` | Referenced resource (e.g. `literature_review_id`) does not exist. | `404` |
| `rate_limited` | Caller exceeded throttling limits. | `429` |
| `timeout` | Upstream took too long to respond. | `504` |
| `internal_error` | Catch-all for unexpected server failures. | `500` |

### 6.3 Examples

```json
{
  "code": "invalid_query",
  "message": "Query must be at least 5 characters long."
}
```

```json
{
  "code": "internal_error",
  "message": "Progressive literature lookup failed."
}
```

---

## 7. Acceptance test vectors

The FE-side parser is built and unit-testable against these vectors. The BE SHOULD include these as integration test cases.

### 7.1 `/literature-review` — happy path

- 5 `review_update` events, one every ~600 ms.
- Each event is cumulative; sources count grows from 1 to 5.
- All events have `does_similar_work_exist: true` and `expected_total_sources: 8`.
- Last event has `is_final: true`, then BE closes the stream.

### 7.2 `/literature-review` — empty results

- Single `review_update` event.
- Body: `{"is_final": true, "does_similar_work_exist": false, "expected_total_sources": 0, "sources": []}`.
- BE closes the stream.

### 7.3 `/literature-review` — error

- Single `error` event with [`ApiError`](#47-apierror) body, e.g. `{"code": "internal_error", "message": "Progressive literature lookup failed."}`.
- BE closes the stream.

### 7.4 `/experiment-plan` — happy path

- HTTP `200 OK`.
- Response shape matches the example in [3.2](#32-post-experiment-plan):
  - 6 materials in `budget.materials`.
  - 5 steps in `time_plan.steps`.
  - 3 of the 5 steps have a non-null `milestone`.
  - `budget.total === 5870.50`, `budget.currency === "USD"`.
  - `time_plan.total_duration_seconds === 1058400` (12 days, 6 hours).

### 7.5 `/experiment-plan` — error

- HTTP `500` (or appropriate 4xx/5xx).
- Body matches [`ApiError`](#47-apierror): `{"code": "internal_error", "message": "Unable to generate experiment plan."}`.

---

## 8. Reference fixtures

The exact JSON shapes the FE parses today live in:

- [`frontend/lib/data/clients/mock_payloads.dart`](../frontend/lib/data/clients/mock_payloads.dart) — canonical `kMockSources` (5 sources) and `kMockExperimentPlanJson` (full plan).
- [`frontend/lib/data/dto/`](../frontend/lib/data/dto) — typed DTO classes mirroring every object in this contract (one file per object).
- [`frontend/lib/data/clients/scientist_backend_client.dart`](../frontend/lib/data/clients/scientist_backend_client.dart) — abstract transport contract.
- [`frontend/lib/data/clients/mock_scientist_backend_client.dart`](../frontend/lib/data/clients/mock_scientist_backend_client.dart) — a runnable reference implementation of the BE behavior described above (timing, SSE envelopes, error semantics).

The BE implementation should produce byte-equivalent JSON to the fixtures for the acceptance vectors in section 7.

---

## 9. Change log

| Version | Date | Changes |
|---|---|---|
| 1.0 | 2026-04-26 | Initial contract: `POST /literature-review` (SSE) and `POST /experiment-plan` (JSON). |
| 1.1 | 2026-04-26 | Added Reviewer feature: `POST /reviews`, `GET /reviews`, `Review` schema. |
