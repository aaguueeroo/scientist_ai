# Backend specification: user-provided OpenAI and Tavily API keys

**Audience:** Backend team (implementation handoff)  
**Related code:** [`backend/app/config/settings.py`](../backend/app/config/settings.py) (`OPENAI_API_KEY`, `TAVILY_API_KEY`), [`backend/app/api/deps.py`](../backend/app/api/deps.py) (`build_openai_client`, `build_tavily_client`, `get_openai_client`, `get_tavily_client`), [`backend/app/main.py`](../backend/app/main.py) (`lifespan` / `app.state`), [`backend/app/clients/openai_client.py`](../backend/app/clients/openai_client.py), [`backend/app/clients/tavily_client.py`](../backend/app/clients/tavily_client.py).  
**Related docs:** [`api_contract.md`](api_contract.md) (global conventions), [`frontend/lib/core/user_api_keys_constants.dart`](../frontend/lib/core/user_api_keys_constants.dart) (header names sent by Marie Query).  
**Status:** Specification — **to be implemented** on the FastAPI side. The Flutter client already sends the headers below on agent routes when the user has saved keys.

---

## 1. Product goal

Scientists run Marie Query with **their own** OpenAI and Tavily credentials. The desktop/mobile app stores secrets locally and forwards them to **this** FastAPI app on each relevant request. The backend must:

1. **Accept** optional per-request OpenAI and Tavily secrets from HTTP headers (see §3).
2. **Use them in memory only** for that request’s agent work — **do not** write these values to the database, disk config, or structured logs.
3. **Route all agent calls** for that request through OpenAI / Tavily clients constructed (or reconfigured) with those secrets when present; otherwise fall back to deployment configuration (see §5).

Naming, onboarding UI, and key lifecycle on the device are **client-only**; the server does not manage named key registries unless product later adds Option B (§8).

---

## 2. Scope — which agents and routes must honor user keys

Anything that today uses [`get_openai_client`](../backend/app/api/deps.py) / [`get_tavily_client`](../backend/app/api/deps.py) with the **process-wide** clients from `app.state` must be able to use **request-scoped** keys when headers are present.

| Area | HTTP entry (examples) | OpenAI | Tavily |
|------|------------------------|--------|--------|
| Literature pipeline | `POST` literature review (streaming) | Yes — QC / LLM steps ([`literature_review.py`](../backend/app/api/literature_review.py), [`literature_qc.py`](../backend/app/agents/literature_qc.py)) | Yes — search / research ([`AbstractTavilyClient`](../backend/app/clients/tavily_client.py)) |
| Experiment plan | `POST` experiment plan | Yes — planner agent ([`experiment_planner.py`](../backend/app/agents/experiment_planner.py)) | Yes — if the planner path uses Tavily ([`experiment_plan.py`](../backend/app/api/experiment_plan.py)) |
| Feedback | `POST` feedback | Yes — relevance / rerank agents ([`feedback.py`](../backend/app/api/feedback.py)) | No — unless a code path is added later |

**Out of scope for v1 unless product extends:** health checks, pure DB reads (`GET` plans, conversations list, etc.), and **debug** endpoints such as [`GET /debug/tavily`](../backend/app/api/debug_tavily.py) may keep using **only** env keys (operator tooling).

The Flutter client currently attaches both headers only on **`literature-review`**, **`experiment-plan`**, and **`feedback`** ([`HttpScientistBackendClient`](../frontend/lib/data/clients/http_scientist_backend_client.dart)). Backend behavior should match those routes at minimum; any additional agent route should follow the same rules when you add it.

---

## 3. Client → server transport (canonical)

| Header | When set | Secret type |
|--------|-----------|-------------|
| `X-OpenAI-API-Key` | Optional on each agent request | OpenAI API key (`sk-…`) |
| `X-Tavily-API-Key` | Optional on each agent request | Tavily API key (per Tavily’s format) |

Rules:

- Values are **opaque strings**; treat as secrets end-to-end.
- If a header is **absent** or **empty** after trim, treat that provider as “use server default for this request” (see §5).
- Do **not** require both headers; either may be sent independently (product may later tighten this).

---

## 4. Persistence model — **in memory only** (chosen for v1)

**Do not** persist user-supplied OpenAI or Tavily secrets to:

- SQL / SQLite,
- files,
- Redis,
- or log sinks.

**Do** keep them only for the **lifetime of the request** (e.g. stack locals, a small request-scoped context object, or short-lived client instances created inside the request handler / dependency chain and discarded before returning the response).

This matches **Option A** from earlier drafts: the client sends the raw secret on each call; the server holds it **only while** running agents for that HTTP request.

---

## 5. Fallback when headers are missing

For each provider independently:

- **If** `X-OpenAI-API-Key` is present and non-empty → use it for **all** OpenAI calls in that request (with your existing cost / model settings from [`Settings`](../backend/app/config/settings.py)).
- **Else** → use `Settings.OPENAI_API_KEY` exactly as today (`build_openai_client` behavior).

Same for Tavily:

- **If** `X-Tavily-API-Key` is present and non-empty → use it for **all** Tavily calls in that request (same `TAVILY_RETRIEVAL_MODE`, `TAVILY_RESEARCH_MODEL`, `SourceTiersConfig` as today).
- **Else** → use `Settings.TAVILY_API_KEY`.

Document and test the edge case: header present but upstream returns **401/403** — return a normal [`ApiError`](../frontend/lib/data/dto/api_error_dto.md)-shaped response with a **stable `code`** (e.g. `openai_unauthorized`, `tavily_unauthorized`) and **no** echo of the secret in `message`.

---

## 6. Implementation checklist (backend)

### 6.1 Read headers safely

- In a **Request**-aware dependency (or middleware that attaches a typed `UserApiKeys` object to `request.state`), read:
  - `request.headers.get("x-openai-api-key")` / `X-OpenAI-API-Key` (case-insensitive per HTTP),
  - `request.headers.get("x-tavily-api-key")`.
- Strip whitespace; empty → treat as unset.

### 6.2 Build or select clients per request

Today [`lifespan`](../backend/app/main.py) builds **one** `RealOpenAIClient` and **one** `RealTavilyClient` from env and stores them on `app.state`.

**Required change:** agent routes must obtain clients that use **user keys when provided**. Practical patterns (pick one and apply consistently):

1. **Per-request factories** — Dependencies such as `get_openai_client_for_request(request: Request) -> AbstractOpenAIClient` that:
   - read user override from headers / `request.state`,
   - return `RealOpenAIClient(api_key=user_or_env, cost_tracker=...)` for this request only,
   - and ensure `await client.aclose()` (or equivalent) **after** the request if you instantiate new async clients per request; **or**
2. **Thin wrapper** — A small `RequestScopedOpenAI` that delegates to either a cached app-state client (env) or a one-off `RealOpenAIClient` built with the user key for this request.

The same idea applies to **`RealTavilyClient`**: constructor already takes `api_key: str` ([`build_tavily_client`](../backend/app/api/deps.py)); build with user key or env key per request.

**Cost tracking:** [`CostTracker`](../backend/app/api/deps.py) is tied to `RealOpenAIClient` today. Decide whether the per-request client gets a **fresh** `CostTracker` for that request only (recommended) or shares process state; document the choice and keep `MAX_REQUEST_USD` behavior predictable.

### 6.3 Wire dependencies into routers and agents

- Replace or augment `Depends(get_openai_client)` / `Depends(get_tavily_client)` on **agent** routes so they receive **request-scoped** clients.
- Ensure every internal call from [`literature_review`](../backend/app/api/literature_review.py), [`experiment_plan`](../backend/app/api/experiment_plan.py), and [`feedback`](../backend/app/api/feedback.py) into agents uses those dependencies — **no** hidden global that still points only at `app.state.openai_client` unless it has been updated for the request.

### 6.4 Lifespan and `app.state`

- Keep **startup** clients on `app.state` as the **defaults** for routes that do not support user keys and for fallback when headers are absent.
- Per-request overrides must **not** mutate `app.state` clients in place (no race between concurrent users).

### 6.5 Observability and security

- **Never** log header names’ values, raw `Authorization`-like payloads, or request bodies containing keys.
- Strip these headers from any debug / trace middleware that dumps headers.
- Redact in exception handlers and `structlog` context.
- **HTTPS** in production between client and API.

### 6.6 Tests

- Unit / integration tests: given mocked headers, assert the **OpenAI** / **Tavily** client factory receives the user key, not env.
- Tests without headers: assert env keys are still used.
- Test concurrent requests with **different** header values do not cross-contaminate (if using any shared mutable state, that’s a bug).

---

## 7. Optional future — server-stored keys (Option B)

If product later requires multi-device sync or vaulting:

- Add registration APIs (`name` + `secret`), opaque `key_id`, encrypted at rest, etc.
- Client would stop sending raw secrets on every call.

Out of scope for the current Marie Query v1 contract; the **in-memory, per-request header** model is the baseline.

---

## 8. What the Flutter client does today (contract alignment)

- Onboarding: **modal dialog** for OpenAI + Tavily when using the real API and the app considers keys “required” (see [`UserApiKeysStore`](../frontend/lib/controllers/user_api_keys_store.dart), [`kValidateProviderApiKeys`](../frontend/lib/core/user_api_keys_constants.dart)).
- Local **secure storage** for secrets; optional prefs flag when validation is relaxed for dev.
- Sends **`X-OpenAI-API-Key`** and **`X-Tavily-API-Key`** on **`literature-review`**, **`experiment-plan`**, and **`feedback`** when non-empty.

Backend implementation should treat this document as the source of truth for **headers**, **in-memory handling**, and **agent wiring** for **OpenAI** and **Tavily** together.
