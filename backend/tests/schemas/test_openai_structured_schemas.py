"""Guardrails for Pydantic models passed to :meth:`openai.chat.completions.parse`.

https://developers.openai.com/api/docs/guides/structured-outputs#supported-schemas
"""

from __future__ import annotations

from collections.abc import Mapping
from typing import Any, Final

import pytest
from pydantic import BaseModel

from app.agents.feedback_relevance import DomainTagClaim, RelevanceClaim
from app.agents.literature_qc import NoveltyClaim
from app.schemas.experiment_plan import ExperimentPlan

# Per OpenAI "Supported `string` properties" — all other `format` values are rejected
# in practice (e.g. Pydantic `HttpUrl` used to emit `format: uri`).

_OPENAI_ALLOWED_STRING_FORMATS: Final = frozenset(
    {
        "date-time",
        "time",
        "date",
        "duration",
        "email",
        "hostname",
        "ipv4",
        "ipv6",
        "uuid",
    }
)

_PYDANTIC_OPENAI_KNOWN_UNSUPPORTED_STRING_FORMATS: Final = frozenset({"uri"})


def _assert_openai_structured_subschema(
    node: Any,
    *,
    path: str = "$",
) -> None:
    if isinstance(node, Mapping):
        # OpenAI: object must set additionalProperties: false
        if node.get("type") == "object" and "properties" in node:
            if node.get("additionalProperties") is not False:
                raise AssertionError(
                    f"{path}: object must have additionalProperties: false (OpenAI requirement); "
                    f"set ConfigDict(extra='forbid') on the Pydantic model. Got: {node!r}"
                )
        fmt = node.get("format")
        if fmt is not None and node.get("type") == "string":
            if fmt not in _OPENAI_ALLOWED_STRING_FORMATS:
                if fmt in _PYDANTIC_OPENAI_KNOWN_UNSUPPORTED_STRING_FORMATS:
                    raise AssertionError(
                        f"{path}: string has format {fmt!r} which OpenAI does not support — "
                        "use plain str + Field(max_length=...) (not HttpUrl). "
                        "https://developers.openai.com/api/docs/guides/structured-outputs#supported-schemas"
                    )
                raise AssertionError(
                    f"{path}: string format {fmt!r} is not in OpenAI's allowed list"
                )
        for key, value in node.items():
            _assert_openai_structured_subschema(value, path=f"{path}.{key}")
    elif isinstance(node, list):
        for i, item in enumerate(node):
            _assert_openai_structured_subschema(item, path=f"{path}[{i}]")


@pytest.mark.parametrize(
    "model",
    [NoveltyClaim, DomainTagClaim, RelevanceClaim, ExperimentPlan],
)
def test_openai_response_format_model_json_schema_is_openai_compliant(
    model: type[BaseModel],
) -> None:
    """Every model in an OpenAI parse() tree must follow OpenAI's JSON Schema subset."""

    schema = model.model_json_schema()
    _assert_openai_structured_subschema(schema)
