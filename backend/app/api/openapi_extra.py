"""Extra OpenAPI components not wired through ``response_model`` (SSE, loose ``Any`` fields)."""

from __future__ import annotations

import json
from typing import Any

from pydantic import BaseModel

from app.schemas.literature_qc import LiteratureQCResult
from app.schemas.pipeline_http import LiteratureReviewSseSource, LiteratureReviewSseUpdateData


def _def_refs_to_openapi(obj: Any) -> Any:
    if isinstance(obj, dict):
        out: dict[str, Any] = {}
        for k, v in obj.items():
            if k == "$ref" and isinstance(v, str) and v.startswith("#/$defs/"):
                name = v.removeprefix("#/$defs/")
                out[k] = f"#/components/schemas/{name}"
            else:
                out[k] = _def_refs_to_openapi(v)
        return out
    if isinstance(obj, list):
        return [_def_refs_to_openapi(i) for i in obj]
    return obj


def _rename_def_key_rec(node: Any, old_name: str, new_name: str) -> None:
    """In-place: rewrite every ``#/$defs/old_name`` to ``#/$defs/new_name``."""
    if isinstance(node, dict):
        for k, v in list(node.items()):
            if k == "$ref" and v == f"#/$defs/{old_name}":
                node[k] = f"#/$defs/{new_name}"
            else:
                _rename_def_key_rec(v, old_name, new_name)
    elif isinstance(node, list):
        for x in node:
            _rename_def_key_rec(x, old_name, new_name)


def _merge_pydantic_model(components: dict[str, Any], model: type[BaseModel], *, as_name: str) -> None:
    """Merge one Pydantic model into OpenAPI ``components['schemas']``."""

    raw = model.model_json_schema()
    # Avoid clashing with OpenAPI's `Reference` component name (JSON Reference).
    if as_name == "LiteratureQCResult" and "Reference" in (raw.get("$defs") or {}):
        d = raw["$defs"]
        d["LiteratureQcReference"] = d.pop("Reference")
        _rename_def_key_rec(raw, "Reference", "LiteratureQcReference")
    with_fixed_refs = _def_refs_to_openapi(json.loads(json.dumps(raw)))
    defs = with_fixed_refs.pop("$defs", {})
    for def_name, def_body in defs.items():
        if def_name not in components:
            components[def_name] = def_body
    components[as_name] = with_fixed_refs


def enrich_openapi_schema(openapi_schema: dict[str, Any]) -> dict[str, Any]:
    """Register SSE and stored :class:`LiteratureQCResult` in ``components.schemas``."""

    dest = openapi_schema.setdefault("components", {}).setdefault("schemas", {})
    for model, as_name in (
        (LiteratureReviewSseSource, "LiteratureReviewSseSource"),
        (LiteratureReviewSseUpdateData, "LiteratureReviewSseUpdateData"),
        (LiteratureQCResult, "LiteratureQCResult"),
    ):
        _merge_pydantic_model(dest, model, as_name=as_name)
    return openapi_schema
