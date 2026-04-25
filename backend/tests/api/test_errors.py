"""Tests for error schemas (Step 3) and FastAPI handlers (extended in Step 7)."""

from __future__ import annotations

import pytest
from pydantic import ValidationError

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
