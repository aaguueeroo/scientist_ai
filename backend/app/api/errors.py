"""Domain exceptions and FastAPI exception handlers.

Every error returned by every endpoint flows through one of these
handlers and is rendered as `app.schemas.errors.ErrorResponse`. The
`ErrorCode` enum is closed (8 codes); rate limiting and unknown plan ids
reuse existing codes.
"""

from __future__ import annotations

from typing import Any

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from app.schemas.errors import ErrorCode, ErrorResponse


class DomainError(Exception):
    """Base class for application-defined errors that map to ErrorCode."""

    code: ErrorCode = ErrorCode.INTERNAL_ERROR
    http_status: int = 500
    default_message: str = "an unexpected error occurred"

    def __init__(
        self,
        message: str | None = None,
        details: dict[str, Any] | None = None,
    ) -> None:
        super().__init__(message or self.default_message)
        self.message = message or self.default_message
        self.details: dict[str, Any] = dict(details or {})


class TavilyUnavailable(DomainError):
    code = ErrorCode.TAVILY_UNAVAILABLE
    http_status = 503
    default_message = "literature search is temporarily unavailable"


class OpenAIUnavailable(DomainError):
    code = ErrorCode.OPENAI_UNAVAILABLE
    http_status = 503
    default_message = "language model is temporarily unavailable"


class OpenAIRateLimited(DomainError):
    code = ErrorCode.OPENAI_RATE_LIMITED
    http_status = 429
    default_message = "rate limit exceeded; try again shortly"


class StructuredOutputInvalid(DomainError):
    code = ErrorCode.STRUCTURED_OUTPUT_INVALID
    http_status = 502
    default_message = "language model returned malformed structured output"


class GroundingFailedRefused(DomainError):
    code = ErrorCode.GROUNDING_FAILED_REFUSED
    http_status = 422
    default_message = "plan refused: insufficient verifiable grounding"


class CostCeilingExceeded(DomainError):
    code = ErrorCode.COST_CEILING_EXCEEDED
    http_status = 402
    default_message = "request would exceed configured cost ceiling"


class InternalError(DomainError):
    code = ErrorCode.INTERNAL_ERROR
    http_status = 500
    default_message = "an unexpected error occurred"


_HTTP_STATUS_FOR_CODE: dict[ErrorCode, int] = {
    ErrorCode.VALIDATION_ERROR: 422,
    ErrorCode.TAVILY_UNAVAILABLE: 503,
    ErrorCode.OPENAI_UNAVAILABLE: 503,
    ErrorCode.OPENAI_RATE_LIMITED: 429,
    ErrorCode.STRUCTURED_OUTPUT_INVALID: 502,
    ErrorCode.GROUNDING_FAILED_REFUSED: 422,
    ErrorCode.COST_CEILING_EXCEEDED: 402,
    ErrorCode.INTERNAL_ERROR: 500,
}


def http_status_for(code: ErrorCode) -> int:
    """Return the HTTP status code that goes with `code` (centralized mapping)."""

    return _HTTP_STATUS_FOR_CODE[code]


def _request_id(request: Request) -> str:
    ctx = getattr(request.state, "request_context", None)
    if ctx is None:
        return ""
    return str(ctx.request_id)


def _render(
    request: Request,
    *,
    code: ErrorCode,
    message: str,
    details: dict[str, Any] | None = None,
) -> JSONResponse:
    body = ErrorResponse(
        code=code,
        message=message,
        details=dict(details or {}),
        request_id=_request_id(request),
    )
    return JSONResponse(
        status_code=http_status_for(code),
        content=body.model_dump(),
    )


async def _domain_error_handler(request: Request, exc: Exception) -> JSONResponse:
    if not isinstance(exc, DomainError):
        return _render(
            request,
            code=ErrorCode.INTERNAL_ERROR,
            message=InternalError.default_message,
        )
    return _render(
        request,
        code=exc.code,
        message=exc.message,
        details=exc.details,
    )


async def _validation_handler(request: Request, exc: Exception) -> JSONResponse:
    if not isinstance(exc, RequestValidationError):
        return _render(
            request,
            code=ErrorCode.INTERNAL_ERROR,
            message=InternalError.default_message,
        )
    return _render(
        request,
        code=ErrorCode.VALIDATION_ERROR,
        message="request body failed validation",
        details={"errors": exc.errors()},
    )


async def _internal_error_handler(request: Request, exc: Exception) -> JSONResponse:
    return _render(
        request,
        code=ErrorCode.INTERNAL_ERROR,
        message=InternalError.default_message,
        details={"type": type(exc).__name__},
    )


def register_exception_handlers(app: FastAPI) -> None:
    """Wire every domain exception + RequestValidationError + Exception handler."""

    app.add_exception_handler(DomainError, _domain_error_handler)
    app.add_exception_handler(RequestValidationError, _validation_handler)
    app.add_exception_handler(Exception, _internal_error_handler)
