"""POST /literature-review: Agent 1, persists QC, streams SSE."""

from __future__ import annotations

import json
import time
import uuid
from collections.abc import AsyncIterator, Iterator
from typing import Annotated, Any

import structlog
from fastapi import APIRouter, Depends, Query, Request
from fastapi.responses import StreamingResponse

from app.agents.literature_qc import LiteratureQCAgent
from app.api.deps import (
    get_citation_resolver,
    get_literature_review_repo,
    get_openai_client,
    get_source_tiers,
    get_tavily_client,
)
from app.api.errors import DomainError
from app.api.middleware import RequestContext
from app.clients.openai_client import AbstractOpenAIClient
from app.clients.tavily_client import AbstractTavilyClient
from app.config.settings import get_settings
from app.config.source_tiers import SourceTiersConfig
from app.observability.timing import truncate_preview
from app.schemas.errors import ErrorCode
from app.schemas.literature_qc import LiteratureQCResult, NoveltyLabel, Reference
from app.schemas.pipeline_http import LiteratureReviewHttpRequest
from app.storage.literature_review_repo import LiteratureReviewRepo
from app.verification.citation_resolver import AbstractCitationResolver


def _qc_debug_dict(qc: LiteratureQCResult) -> dict[str, Any]:
    """Safe-for-JSON summary for DEBUG logs (truncated URLs)."""

    out: dict[str, Any] = {
        "novelty": qc.novelty.value,
        "reference_count": len(qc.references),
        "references": [
            {
                "url": truncate_preview(str(r.url), 200),
                "verified": r.verified,
                "is_similarity_suggestion": r.is_similarity_suggestion,
                "tier": r.tier.value,
            }
            for r in qc.references
        ],
        "has_similarity_suggestion": qc.similarity_suggestion is not None,
        "tier_0_drops": qc.tier_0_drops,
        "confidence": qc.confidence,
    }
    if qc.similarity_suggestion is not None:
        s = qc.similarity_suggestion
        out["similarity_suggestion"] = {
            "url": truncate_preview(str(s.url), 200),
            "verified": s.verified,
            "is_similarity_suggestion": s.is_similarity_suggestion,
            "tier": s.tier.value,
        }
    return out


# OpenAPI: text/event-stream (line-oriented SSE; newlines matter). Shorter chunks
# keep Swagger from reflowing badly. Full ``sources`` field list is in
# ``components.schemas.LiteratureReviewSseSource`` in ``/openapi.json``.
_LITERATURE_SSE_OPENAPI_EXAMPLE = (
    'data: {"event":"review_update","data":{'
    '"is_final":false,"does_similar_work_exist":true,'
    '"expected_total_sources":1,"sources":[]}}\n\n'
    'data: {"event":"review_update","data":{'
    '"is_final":true,"does_similar_work_exist":true,'
    '"expected_total_sources":1,'
    '"sources":[{"author":"Verified source (tier-assigned)",'
    '"title":"…","url":"https://www.example.com/article",'
    '"date_of_publication":"1970-01-01","abstract":"…",'
    '"doi":"10.0000/…","verified":true,'
    '"unverified_similarity_suggestion":false,'
    '"tier":"tier_1_peer_reviewed"}],'
    '"literature_review_id":"lr-8e7d6c5b4a39281726354a1b2c3d4e5f"}}\n\n'
)

# Second shape: no verified rows; one row is an unverified similar link only
# (Tavily / open-web / LLM last resort). See LiteratureQCResult.similarity_suggestion.
_LITERATURE_SSE_OPENAPI_EXAMPLE_SIMILARITY_ONLY: str = "data: " + json.dumps(
    {
        "event": "review_update",
        "data": {
            "is_final": True,
            "does_similar_work_exist": False,
            "expected_total_sources": 1,
            "sources": [
                {
                    "author": "Unverified (similarity suggestion)",
                    "title": "Possibly related paper",
                    "url": "https://example.com/possible-match",
                    "date_of_publication": "1970-01-01",
                    "abstract": (
                        "[Unverified — similar content only, not HTTP-verified] …"
                    ),
                    "doi": "10.0000/unspecified",
                    "verified": False,
                    "unverified_similarity_suggestion": True,
                    "tier": "tier_3_general_web",
                }
            ],
            "literature_review_id": "lr-0a1b2c3d4e5f6789abcdef12345670",
        },
    },
    ensure_ascii=True,
) + "\n\n"

router = APIRouter(tags=["Literature"])
_log = structlog.get_logger("app")


def _reference_to_fe_source(ref: Reference) -> dict[str, Any]:
    """Map internal `Reference` to the Flutter `Source` JSON shape (author, abstract, ...)."""

    doi = (ref.doi or "").strip() or "10.0000/unspecified"
    body = (ref.why_relevant or ref.title)[:4000]
    if ref.is_similarity_suggestion:
        body = f"[Unverified — similar content only, not HTTP-verified] {body}"
    return {
        "author": (
            "Unverified (similarity suggestion)"
            if ref.is_similarity_suggestion
            else "Verified source (tier-assigned)"
        ),
        "title": ref.title,
        "url": str(ref.url),
        "date_of_publication": "1970-01-01",
        "abstract": body,
        "doi": doi,
        "verified": not ref.is_similarity_suggestion and ref.verified,
        "unverified_similarity_suggestion": ref.is_similarity_suggestion,
        "tier": ref.tier.value,
        "tavily_score": ref.tavily_score,
    }


def _does_similar_work_exist(novelty: NoveltyLabel) -> bool:
    return novelty in (NoveltyLabel.SIMILAR_WORK_EXISTS, NoveltyLabel.EXACT_MATCH)


def _qc_sse_sources(
    qc: LiteratureQCResult,
) -> tuple[list[dict[str, Any]], int, bool]:
    """FE-shaped sources list, count, and novelty flag (shared by stream and replay)."""
    display_refs: list[Reference] = list(qc.references)
    if qc.similarity_suggestion is not None:
        display_refs.append(qc.similarity_suggestion)
    sources = [_reference_to_fe_source(r) for r in display_refs]
    n = len(sources)
    does_similar = _does_similar_work_exist(qc.novelty)
    return sources, n, does_similar


def _final_review_data_from_qc(
    qc: LiteratureQCResult, literature_review_id: str
) -> dict[str, Any]:
    """Payload for the final `review_update` (also used for GET replay of stored QC)."""
    sources, n, does_similar = _qc_sse_sources(qc)
    if n == 0:
        return {
            "is_final": True,
            "does_similar_work_exist": does_similar,
            "expected_total_sources": 0,
            "sources": [],
            "literature_review_id": literature_review_id,
        }
    return {
        "is_final": True,
        "does_similar_work_exist": does_similar,
        "expected_total_sources": n,
        "sources": sources,
        "literature_review_id": literature_review_id,
    }


def _stream_review_events(
    *,
    qc: LiteratureQCResult,
    literature_review_id: str,
) -> Iterator[bytes]:
    """Emit cumulative `review_update` envelopes, then a final one with the stored id."""

    sources, n, does_similar = _qc_sse_sources(qc)
    if n == 0:
        env = {
            "event": "review_update",
            "data": _final_review_data_from_qc(qc, literature_review_id),
        }
        yield f"data: {json.dumps(env, ensure_ascii=False)}\n\n".encode()
        return
    for i in range(1, n + 1):
        is_final = i == n
        if is_final:
            data_obj = _final_review_data_from_qc(qc, literature_review_id)
        else:
            data_obj = {
                "is_final": False,
                "does_similar_work_exist": does_similar,
                "expected_total_sources": n,
                "sources": sources[:i],
            }
        env = {"event": "review_update", "data": data_obj}
        yield f"data: {json.dumps(env, ensure_ascii=False)}\n\n".encode()


@router.get(
    "/literature-reviews",
    summary="List stored literature reviews",
    description=(
        "Returns up to `limit` rows from the literature store (newest first). "
        "Each item includes the search `query` and `literature_review_id` used with "
        "`POST /experiment-plan`. Only rows with the current schema version are included."
    ),
)
async def list_literature_reviews(
    repo: Annotated[LiteratureReviewRepo, Depends(get_literature_review_repo)],
    limit: Annotated[int, Query(ge=1, le=200, description="Max rows to return.")] = 100,
) -> dict[str, Any]:
    return {"literature_reviews": await repo.list_literature_reviews(limit=limit)}


@router.post(
    "/literature-review",
    summary="Literature triage (Agent 1) — stream via SSE",
    response_class=StreamingResponse,
    description=(
        "Agent 1 (Tavily, gpt-4.1-mini, citation resolver) persists a row as `lr-uuid`. "
        "The body is `text/event-stream` (SSE), not one JSON object.\n\n"
        "- Send `Accept: text/event-stream`. Each `data:` line is JSON, then a blank line.\n"
        "- Payload: `event` is `review_update` or `error`, plus `data` object.\n"
        "- `review_update`: cumulative `sources`, `is_final`, `does_similar_work_exist`, "
        "and on the last event `literature_review_id`.\n"
        "- Each `sources[]` item is shaped like **LiteratureReviewSseSource** in "
        "`/openapi.json` `components.schemas` (see `unverified_similarity_suggestion`, "
        "`verified`, `tier`, `author`, `abstract`).\n"
        "- When the citation resolver returns **no** verified references, a single "
        "last-resort link may be appended: `unverified_similarity_suggestion: true` "
        "(Tavily allowlist, optional open-web Tavily fallback, or a non–tier-0 LLM URL). "
        "Stored `LiteratureQCResult` (including `similarity_suggestion`) is the same "
        "shape you get in `POST /experiment-plan` `qc`.\n"
        "- `error`: `data` has `code` and `message`. Use `X-Request-ID` to correlate logs."
    ),
    responses={
        200: {
            "description": (
                "Event stream; parse line by line. The **data** object for `review_update` "
                "matches `LiteratureReviewSseUpdateData` in the OpenAPI "
                "`components.schemas`."
            ),
            "content": {
                "text/event-stream": {
                    "schema": {
                        "type": "string",
                        "description": (
                            "Text stream: lines `data: <json>`; parse JSON, then a blank line. "
                            "The JSON object has `event` and `data`; for `review_update`, "
                            "`data` is documented as **LiteratureReviewSseUpdateData** in "
                            "`/openapi.json` `components.schemas`."
                        ),
                    },
                    "example": _LITERATURE_SSE_OPENAPI_EXAMPLE,
                    "examples": {
                        "Cumulative_with_verified_source": {
                            "summary": "Two `review_update` lines; final with verified source",
                            "value": _LITERATURE_SSE_OPENAPI_EXAMPLE,
                        },
                        "Final_unverified_similarity_only": {
                            "summary": (
                                "No verified refs; one similar row (resolver not applied)"
                            ),
                            "value": _LITERATURE_SSE_OPENAPI_EXAMPLE_SIMILARITY_ONLY,
                        },
                    },
                }
            },
            "headers": {
                "X-Request-ID": {
                    "description": "Trace id (also in server log request_id).",
                    "schema": {"type": "string"},
                }
            },
        }
    },
)
async def post_literature_review(
    body: LiteratureReviewHttpRequest,
    request: Request,
    openai: Annotated[AbstractOpenAIClient, Depends(get_openai_client)],
    tavily: Annotated[AbstractTavilyClient, Depends(get_tavily_client)],
    citation_resolver: Annotated[AbstractCitationResolver, Depends(get_citation_resolver)],
    source_tiers: Annotated[SourceTiersConfig, Depends(get_source_tiers)],
    repo: Annotated[LiteratureReviewRepo, Depends(get_literature_review_repo)],
) -> StreamingResponse:
    """Run literature QC (Tavily + gpt-4.1-mini) and stream SSE `review_update` / `error` events."""

    ctx: RequestContext = request.state.request_context
    ctx.agent_calls += 1

    async def body_bytes() -> AsyncIterator[bytes]:
        # Streaming: this generator runs *after* the 200 is returned, so
        # `http.request.complete` logs a short latency (response headers only).
        # Use `app.literature_review.*` DEBUG lines for real work duration and I/O.
        cfg = get_settings()
        prev = cfg.LOG_DEBUG_PREVIEW_CHARS
        stream_t0 = time.perf_counter()
        _log.info(
            "app.literature_review.stream_open",
            request_id=ctx.request_id,
            client_request_id=body.request_id,
            query_len=len(body.query),
        )
        _log.debug(
            "app.literature_review.input",
            request_id=ctx.request_id,
            client_request_id=body.request_id,
            query_preview=truncate_preview(body.query, prev),
            query_len=len(body.query),
        )
        try:
            agent = LiteratureQCAgent(
                openai=openai,
                tavily=tavily,
                citation_resolver=citation_resolver,
                source_tiers=source_tiers,
            )
            t_agent0 = time.perf_counter()
            qc = await agent.run(
                hypothesis=body.query,
                request_id=ctx.request_id,
            )
            agent_ms = int((time.perf_counter() - t_agent0) * 1000)
            _log.debug(
                "app.literature_review.agent_result",
                request_id=ctx.request_id,
                agent_run_ms=agent_ms,
                **_qc_debug_dict(qc),
            )
            literature_review_id = f"lr-{uuid.uuid4().hex}"
            _log.info(
                "app.literature_review.db_save_begin",
                request_id=ctx.request_id,
                literature_review_id=literature_review_id,
            )
            t_save0 = time.perf_counter()
            await repo.save(
                literature_review_id=literature_review_id,
                request_id=ctx.request_id,
                query=body.query,
                qc=qc,
            )
            _log.debug(
                "app.literature_review.db_save_ms",
                request_id=ctx.request_id,
                elapsed_ms=int((time.perf_counter() - t_save0) * 1000),
            )
            _log.info(
                "app.literature_review.saved",
                request_id=ctx.request_id,
                client_request_id=body.request_id,
                literature_review_id=literature_review_id,
                novelty=qc.novelty.value,
            )
            chunk_idx = 0
            for chunk in _stream_review_events(
                qc=qc,
                literature_review_id=literature_review_id,
            ):
                chunk_idx += 1
                try:
                    preview = chunk[: min(500, len(chunk))].decode("utf-8", errors="replace")
                except Exception:  # pragma: no cover
                    preview = "<binary>"
                _log.debug(
                    "app.literature_review.sse_chunk",
                    request_id=ctx.request_id,
                    chunk_index=chunk_idx,
                    chunk_bytes=len(chunk),
                    data_preview=truncate_preview(preview, 400),
                )
                yield chunk
            _log.info(
                "app.literature_review.stream_done",
                request_id=ctx.request_id,
                literature_review_id=literature_review_id,
            )
            _log.debug(
                "app.literature_review.stream_total",
                request_id=ctx.request_id,
                total_elapsed_ms=int((time.perf_counter() - stream_t0) * 1000),
                agent_run_ms=agent_ms,
                sse_event_count=chunk_idx,
            )
        except DomainError as err:
            _log.info(
                "app.literature_review.domain_error",
                request_id=ctx.request_id,
                code=err.code.value,
                message=err.message,
            )
            code = err.code.value
            msg = err.message
            env = {
                "event": "error",
                "data": {
                    "code": code,
                    "message": msg,
                },
            }
            yield f"data: {json.dumps(env, ensure_ascii=False)}\n\n".encode()
        except Exception as exc:  # pragma: no cover - safety net
            _log.exception(
                "app.literature_review.unexpected_error",
                request_id=ctx.request_id,
                error=str(exc)[:500],
            )
            env = {
                "event": "error",
                "data": {
                    "code": ErrorCode.INTERNAL_ERROR.value,
                    "message": str(exc)[:2000],
                },
            }
            yield f"data: {json.dumps(env, ensure_ascii=False)}\n\n".encode()

    return StreamingResponse(
        body_bytes(),
        media_type="text/event-stream; charset=utf-8",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )
