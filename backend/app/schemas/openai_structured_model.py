"""Base model for Pydantic types used with :meth:`openai.chat.completions.parse`.

OpenAI Structured Outputs accept only a *subset* of JSON Schema. In particular:

- Every object in the schema must set ``additionalProperties: false`` — Pydantic
  v2 does this when ``model_config = ConfigDict(extra="forbid")`` on **each**
  object type in the tree.
- String ``format`` is restricted; **``uri`` is not supported** (use plain
  ``str`` and ``Field(max_length=...)`` for URLs, not :class:`pydantic.HttpUrl`).

Full rules:
https://developers.openai.com/api/docs/guides/structured-outputs#supported-schemas
"""

from __future__ import annotations

from pydantic import BaseModel, ConfigDict

__all__ = ("OpenAIStructuredModel",)


class OpenAIStructuredModel(BaseModel):
    """Use as the base class for *every* model in an OpenAI ``response_format`` tree."""

    model_config = ConfigDict(extra="forbid")
