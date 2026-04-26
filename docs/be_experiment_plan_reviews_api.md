# Experiment plan reviews — backend API (handoff)

**Audience:** Backend team  
**Status:** Spec for implementation  
**Source alignment:** This mirrors **§3.3, §3.4, and §4.8** of [`api_contract.md`](api_contract.md) (Scientist AI API v1.1). The full project contract remains authoritative; this file is a **focused handoff** for the plan-review / Reviewer feature.

## Scope

The mobile app lets users, after a generated **experiment plan**, submit:

- **Field-level corrections** (suggested edits to a single field)
- **Comments** (free text anchored to a substring of a field)
- **Section feedback** (like or dislike on a major plan section)

Each of those is persisted as one **`Review`**. The backend must expose two HTTP resources so the app can **submit** and **list** reviews for the current user.

**Out of scope for this document:** `POST /feedback` in the main backend codebase is a **different** contract (correction text + `plan_id` for few-shot learning on later plan generation). The Reviewer feature uses **`/reviews`** and the JSON shape below, not that route.

---

## Endpoints summary

| # | Method | Path | Purpose |
|---|--------|------|--------|
| 1 | `POST` | `/reviews` | Persist one `Review` (one correction, one comment, or one like/dislike). |
| 2 | `GET` | `/reviews` | Return every `Review` for the authenticated user (newest first). |

---

## Global conventions (concise)

| Topic | Rule |
|-------|------|
| `Content-Type` (JSON) | `application/json; charset=utf-8` |
| JSON keys | `snake_case` everywhere. |
| Success | `200 OK` and JSON body as specified. |
| Errors | `4xx` / `5xx` with JSON body shaped like **`ApiError`** (see [Error response](#error-response)). |
| **Auth** | TBD. Until defined, the BE may use an internal placeholder; the FE will send the agreed header when specified in the main contract. |

---

## 1. `POST /reviews`

**Purpose:** Store a single review. The app sends one HTTP request per atomic user action (one correction, one comment, or one section like/dislike).

**Request**

- **Method:** `POST`
- **Path:** `/reviews`
- **Headers:** `Content-Type: application/json; charset=utf-8`, `Accept: application/json`
- **Body:** One [`Review`](#review-object) object (see field definitions below). The client may supply `id` and `created_at`; the **server may normalize or replace** them in the response.

**Response (success)**

- **Status:** `200 OK`
- **Body:** The **stored** `Review` (same structure as the request, after any server-side normalisation, e.g. server-generated `id` / `created_at`).

**Response (error)**

- See [Error response](#error-response). Typical: `400` for invalid payload (e.g. unknown `kind` or malformed `payload`).

### 1.1 Request example — correction (field-level edit / suggestion)

```json
{
  "id": "review_lq2x8aab_1_pn8z",
  "created_at": "2026-04-26T22:10:00.000Z",
  "conversation_id": "Does cold exposure improve insulin sensitivity in healthy adults?",
  "query": "Does cold exposure improve insulin sensitivity in healthy adults?",
  "original_plan": {
    "description": "A short plan summary.",
    "budget": {
      "total": 1000.0,
      "currency": "USD",
      "materials": []
    },
    "time_plan": {
      "total_duration_seconds": 0,
      "steps": [
        {
          "number": 1,
          "duration_seconds": 0,
          "name": "Run pilot experiment",
          "description": "Details.",
          "milestone": null
        }
      ]
    }
  },
  "kind": "correction",
  "payload": {
    "target": "step[step_1].name",
    "before": "Run pilot experiment",
    "after": "Run pilot assay with positive controls"
  }
}
```

**Response (success) — same shape, echoed/stored**

```json
{
  "id": "review_lq2x8aab_1_pn8z",
  "created_at": "2026-04-26T22:10:00.000Z",
  "conversation_id": "Does cold exposure improve insulin sensitivity in healthy adults?",
  "query": "Does cold exposure improve insulin sensitivity in healthy adults?",
  "original_plan": { },
  "kind": "correction",
  "payload": {
    "target": "step[step_1].name",
    "before": "Run pilot experiment",
    "after": "Run pilot assay with positive controls"
  }
}
```

*(The `original_plan` value is abbreviated as `{ }` in examples; the real payload is a full [Experiment plan snapshot](#experimentplan-snapshot).)*

### 1.2 Request example — comment (anchored text)

```json
{
  "id": "review_lq2x8aac_2_q3sa",
  "created_at": "2026-04-26T22:11:00.000Z",
  "conversation_id": "Does cold exposure improve insulin sensitivity in healthy adults?",
  "query": "Does cold exposure improve insulin sensitivity in healthy adults?",
  "original_plan": { },
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

**Response (success):** `200` + same `Review` object as stored.

### 1.3 Request example — section like / dislike

```json
{
  "id": "review_lq2x8aad_3_r4tb",
  "created_at": "2026-04-26T22:12:00.000Z",
  "conversation_id": "Does cold exposure improve insulin sensitivity in healthy adults?",
  "query": "Does cold exposure improve insulin sensitivity in healthy adults?",
  "original_plan": { },
  "kind": "feedback",
  "payload": {
    "section": "steps",
    "polarity": "like"
  }
}
```

**Response (success):** `200` + same `Review` object as stored.

---

## 2. `GET /reviews`

**Purpose:** Return all reviews for the current user, for the Reviewer list on app load.

**Request**

- **Method:** `GET`
- **Path:** `/reviews`
- **Headers:** `Accept: application/json`

**Response (success)**

- **Status:** `200 OK`
- **Content-Type:** `application/json; charset=utf-8`
- **Body:**

```json
{
  "reviews": [
    {
      "id": "review_lq2x8aad_3_r4tb",
      "created_at": "2026-04-26T22:12:00.000Z",
      "conversation_id": "Does cold exposure improve insulin sensitivity in healthy adults?",
      "query": "Does cold exposure improve insulin sensitivity in healthy adults?",
      "original_plan": { },
      "kind": "feedback",
      "payload": {
        "section": "steps",
        "polarity": "like"
      }
    },
    {
      "id": "review_lq2x8aac_2_q3sa",
      "created_at": "2026-04-26T22:11:00.000Z",
      "conversation_id": "Does cold exposure improve insulin sensitivity in healthy adults?",
      "query": "Does cold exposure improve insulin sensitivity in healthy adults?",
      "original_plan": { },
      "kind": "comment",
      "payload": {
        "target": "plan.description",
        "quote": "controlled T-cell expansion assay",
        "start": 2,
        "end": 36,
        "body": "Clarify the donor pool size in this sentence."
      }
    }
  ]
}
```

| Field | Type | Required | Notes |
|-------|------|----------|--------|
| `reviews` | array of `Review` | yes | Ordered by `created_at` **descending** (most recent first). May be `[]`. |

**Response (error):** See [Error response](#error-response) (e.g. `401` when auth is enforced).

---

## `Review` object

| Field | Type | Required | Notes |
|-------|------|----------|--------|
| `id` | string | yes | Stable id. Client may generate; **server may replace** on write. |
| `created_at` | string | yes | ISO 8601 **with** timezone, e.g. `2026-04-26T22:10:00Z` or with fractional seconds. |
| `conversation_id` | string | yes | v1: often the same as the user’s research **query** string; may later be a real conversation id. |
| `query` | string | yes | The research question (denormalised for display). |
| `original_plan` | object | yes | Full **`ExperimentPlan`** snapshot **before** the user’s edits, at the time the review was created. |
| `kind` | string | yes | One of: `"correction"`, `"comment"`, `"feedback"`. |
| `payload` | object | yes | Shape depends on `kind` (below). |

### `payload` when `kind` is `"correction"`

| Field | Type | Required | Notes |
|-------|------|----------|--------|
| `target` | string | yes | Path to a **single** field. Examples: `plan.description`, `plan.budget.total`, `plan.timePlan.totalDuration`, `step[<step_id>].<field>`, `material[<material_id>].<field>`. For steps, `<field>` is one of: `name`, `description`, `duration`, `milestone`. For materials: `title`, `catalogNumber`, `description`, `amount`, `price`. |
| `before` | any | yes | Previous value (type matches the field: string, number, int seconds, etc.). |
| `after` | any | yes | New value (same type as `before`). |

### `payload` when `kind` is `"comment"`

| Field | Type | Required | Notes |
|-------|------|----------|--------|
| `target` | string | yes | Same path vocabulary as `correction`. |
| `quote` | string | yes | Selected substring. |
| `start` | int | yes | Inclusive start index in the target string. |
| `end` | int | yes | Exclusive end index; `text.substring(start, end)` equals `quote`. |
| `body` | string | yes | Comment text. |

### `payload` when `kind` is `"feedback"`

| Field | Type | Required | Notes |
|-------|------|----------|--------|
| `section` | string | yes | One of: `totalTime`, `budget`, `timeline`, `steps`, `materials`. |
| `polarity` | string | yes | `like` or `dislike`. |

---

## `ExperimentPlan` snapshot

`original_plan` must match the **`ExperimentPlan`** schema in the main contract ([`api_contract.md` §4.2](api_contract.md) and related §4.3–4.6, §4.9). The server should accept and return the same structure the app receives from `POST /experiment-plan`.

**Minimal example** (valid shape; real requests may be larger):

```json
{
  "description": "One-paragraph plan summary.",
  "budget": {
    "total": 500.0,
    "currency": "USD",
    "materials": [
      {
        "title": "Reagent A",
        "catalog_number": "CAT-1",
        "description": "For the assay.",
        "amount": 1,
        "price": 50.0
      }
    ]
  },
  "time_plan": {
    "total_duration_seconds": 86400,
    "steps": [
      {
        "number": 1,
        "duration_seconds": 86400,
        "name": "First step",
        "description": "Do the thing.",
        "milestone": "Pilot data collected"
      }
    ]
  }
}
```

Optional keys such as `steps_section_source_refs` and `materials_section_source_refs` (arrays of `PlanSourceRef`) follow the main contract; unknown keys on read should be ignored on both sides if agreed globally.

---

## Error response

For failed `POST /reviews` and `GET /reviews` requests, return a JSON body compatible with the app’s `ApiError` handling:

| Field | Type | Required | Notes |
|-------|------|----------|--------|
| `code` | string | yes | e.g. `invalid_query`, `unauthorized`, `rate_limited`, `internal_error`. |
| `message` | string | yes | Human-readable. |
| `request_id` | string | no | If present, echoed from request headers or generated; useful for support. |
| `details` | any | no | Optional diagnostic payload. |

**Example**

```json
{
  "code": "invalid_query",
  "message": "Unknown review kind or malformed payload."
}
```

---

## Change log

| Version | Date | Change |
|---------|------|--------|
| 1.0 | 2026-04-26 | Initial handoff: `POST /reviews`, `GET /reviews`, `Review` + payloads + `ApiError`. |
