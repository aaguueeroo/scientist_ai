"""Tests for error schemas (Step 3) and FastAPI handlers (Step 7)."""

from __future__ import annotations

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from pydantic import BaseModel, Field, ValidationError

from app.api.errors import (
    CostCeilingExceeded,
    GroundingFailedRefused,
    InternalError,
    OpenAIRateLimited,
    OpenAIUnavailable,
    StructuredOutputInvalid,
    TavilyUnavailable,
    register_exception_handlers,
)
from app.api.middleware import RequestContextMiddleware
from app.schemas.errors import ErrorCode, ErrorResponse


def test_error_code_enum_contains_exactly_eight_codes() -> None:
    expected = {
        "validation_error",
        "tavily_unavailable",
        "openai_unavailable",
        "openai_rate_limited",
        "structured_output_invalid",
        "grounding_failed_refused",
        "cost_ceiling_exceeded",
        "internal_error",
    }
    actual = {code.value for code in ErrorCode}
    assert actual == expected


def test_error_response_serializes_with_required_fields() -> None:
    response = ErrorResponse(
        code=ErrorCode.VALIDATION_ERROR,
        message="hypothesis must be non-empty",
        details={"field": "hypothesis"},
        request_id="01HW4K3M9N1Q7VS6E2YBZ5XJDA",
    )
    payload = response.model_dump()
    assert payload["code"] == "validation_error"
    assert payload["message"] == "hypothesis must be non-empty"
    assert payload["details"] == {"field": "hypothesis"}
    assert payload["request_id"] == "01HW4K3M9N1Q7VS6E2YBZ5XJDA"


def test_error_response_rejects_unknown_code() -> None:
    with pytest.raises(ValidationError):
        ErrorResponse.model_validate(
            {
                "code": "not_a_real_code",
                "message": "boom",
                "request_id": "01HW4K3M9N1Q7VS6E2YBZ5XJDA",
            }
        )


# --- Step 7: per-code FastAPI handler tests --------------------------------


class _Body(BaseModel):
    name: str = Field(min_length=1)


def _build_app() -> FastAPI:
    app = FastAPI()
    app.add_middleware(RequestContextMiddleware)
    register_exception_handlers(app)

    @app.post("/_test/validation")
    async def validation_route(body: _Body) -> dict[str, str]:
        return {"name": body.name}

    @app.get("/_test/tavily")
    async def tavily_route() -> None:
        raise TavilyUnavailable(details={"upstream_status": 503})

    @app.get("/_test/openai-unavailable")
    async def openai_unavailable_route() -> None:
        raise OpenAIUnavailable(details={"agent": "experiment_planner"})

    @app.get("/_test/openai-rate-limited")
    async def openai_rate_limited_route() -> None:
        raise OpenAIRateLimited(details={"agent": "experiment_planner", "retry_after_s": 12})

    @app.get("/_test/structured-output")
    async def structured_output_route() -> None:
        raise StructuredOutputInvalid(details={"agent": "experiment_planner", "attempts": 2})

    @app.get("/_test/grounding")
    async def grounding_route() -> None:
        raise GroundingFailedRefused(details={"verified_count": 0, "unverified_count": 5})

    @app.get("/_test/cost-ceiling")
    async def cost_ceiling_route() -> None:
        raise CostCeilingExceeded(
            details={"projected_usd": 0.71, "ceiling_usd": 0.60, "agent": "experiment_planner"}
        )

    @app.get("/_test/internal")
    async def internal_route() -> None:
        raise InternalError()

    @app.get("/_test/raw-exc")
    async def raw_exc_route() -> None:
        raise RuntimeError("boom")

    return app


def _client(app: FastAPI) -> AsyncClient:
    transport = ASGITransport(app=app, raise_app_exceptions=False)
    return AsyncClient(transport=transport, base_url="http://test")


@pytest.mark.asyncio
async def test_errors_validation_error_returns_422_with_error_response() -> None:
    async with _client(_build_app()) as client:
        response = await client.post("/_test/validation", json={"name": ""})
    assert response.status_code == 422
    body = response.json()
    assert body["code"] == ErrorCode.VALIDATION_ERROR.value
    assert body["request_id"]


@pytest.mark.asyncio
async def test_errors_tavily_unavailable_returns_503_with_error_response() -> None:
    async with _client(_build_app()) as client:
        response = await client.get("/_test/tavily")
    assert response.status_code == 503
    body = response.json()
    assert body["code"] == ErrorCode.TAVILY_UNAVAILABLE.value
    assert body["details"]["upstream_status"] == 503


@pytest.mark.asyncio
async def test_errors_openai_unavailable_returns_503_with_error_response() -> None:
    async with _client(_build_app()) as client:
        response = await client.get("/_test/openai-unavailable")
    assert response.status_code == 503
    body = response.json()
    assert body["code"] == ErrorCode.OPENAI_UNAVAILABLE.value


@pytest.mark.asyncio
async def test_errors_openai_rate_limited_returns_429_with_error_response() -> None:
    async with _client(_build_app()) as client:
        response = await client.get("/_test/openai-rate-limited")
    assert response.status_code == 429
    body = response.json()
    assert body["code"] == ErrorCode.OPENAI_RATE_LIMITED.value
    assert body["details"]["retry_after_s"] == 12


@pytest.mark.asyncio
async def test_errors_structured_output_invalid_returns_502_with_error_response() -> None:
    async with _client(_build_app()) as client:
        response = await client.get("/_test/structured-output")
    assert response.status_code == 502
    body = response.json()
    assert body["code"] == ErrorCode.STRUCTURED_OUTPUT_INVALID.value


@pytest.mark.asyncio
async def test_errors_grounding_failed_refused_returns_422_with_error_response() -> None:
    async with _client(_build_app()) as client:
        response = await client.get("/_test/grounding")
    assert response.status_code == 422
    body = response.json()
    assert body["code"] == ErrorCode.GROUNDING_FAILED_REFUSED.value


@pytest.mark.asyncio
async def test_errors_cost_ceiling_exceeded_returns_402_with_error_response() -> None:
    async with _client(_build_app()) as client:
        response = await client.get("/_test/cost-ceiling")
    assert response.status_code == 402
    body = response.json()
    assert body["code"] == ErrorCode.COST_CEILING_EXCEEDED.value
    assert body["details"]["ceiling_usd"] == 0.60


@pytest.mark.asyncio
async def test_errors_internal_error_returns_500_with_error_response() -> None:
    async with _client(_build_app()) as client:
        response = await client.get("/_test/internal")
    assert response.status_code == 500
    body = response.json()
    assert body["code"] == ErrorCode.INTERNAL_ERROR.value


@pytest.mark.asyncio
async def test_errors_raw_exception_falls_through_to_internal_error() -> None:
    async with _client(_build_app()) as client:
        response = await client.get("/_test/raw-exc")
    assert response.status_code == 500
    body = response.json()
    assert body["code"] == ErrorCode.INTERNAL_ERROR.value


@pytest.mark.asyncio
async def test_errors_response_includes_active_request_id() -> None:
    async with _client(_build_app()) as client:
        response = await client.get(
            "/_test/cost-ceiling",
            headers={"X-Request-ID": "rid-from-client"},
        )
    body = response.json()
    assert body["request_id"] == "rid-from-client"
