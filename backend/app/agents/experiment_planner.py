"""Runtime Agent 3 — Experiment planner.

Calls `OpenAIClient.parse(model="gpt-4.1", response_format=ExperimentPlan,
seed=23, temperature=0)` once. On schema-violating output (any exception
raised by the structured-output layer) the agent retries exactly once;
on the second failure it raises `StructuredOutputInvalid`.

The agent does not run resolvers itself: grounding (citation + catalog
verification, `grounding_summary` aggregation) is done by the grounding
pipeline (Step 30) on the returned `ExperimentPlan`.
"""

from __future__ import annotations

import time
from dataclasses import dataclass

from app.api.errors import StructuredOutputInvalid
from app.clients.openai_client import (
    AbstractOpenAIClient,
    ChatMessage,
    ParsedResult,
)
from app.config.settings import Settings, get_settings
from app.observability.logging import emit_agent_call_complete
from app.prompts.loader import load_role, prompt_versions
from app.runtime.pipeline_state import PipelineState
from app.schemas.experiment_plan import ExperimentPlan, Material, ProtocolStep
from app.schemas.literature_qc import Reference

_AGENT_NAME = "experiment_planner"
_ROLE_FILE = "experiment_planner.md"
_MAX_PARSE_ATTEMPTS = 2


@dataclass
class ExperimentPlannerAgent:
    """Runtime Agent 3.

    Constructed once per request from the FastAPI dependency layer.
    `openai` is the only required dependency; `settings` is injected for
    tests that want to override the cost / token budget.
    """

    openai: AbstractOpenAIClient
    settings: Settings | None = None

    async def run(self, *, state: PipelineState) -> ExperimentPlan:
        cfg = self.settings or get_settings()
        role = load_role(_ROLE_FILE)
        versions = prompt_versions()

        messages = [
            ChatMessage(role="system", content=role),
            ChatMessage(role="user", content=_format_user_payload(state)),
        ]

        last_error: BaseException | None = None
        parsed: ParsedResult[ExperimentPlan] | None = None
        start = time.perf_counter()
        for _attempt in range(_MAX_PARSE_ATTEMPTS):
            try:
                parsed = await self.openai.parse(
                    model=cfg.OPENAI_MODEL_EXPERIMENT_PLANNER,
                    messages=messages,
                    response_format=ExperimentPlan,
                    temperature=cfg.OPENAI_TEMP_EXPERIMENT_PLANNER,
                    seed=cfg.OPENAI_SEED_EXPERIMENT_PLANNER,
                    max_tokens=cfg.OPENAI_MAX_TOKENS_EXPERIMENT_PLANNER,
                )
                break
            except StructuredOutputInvalid:
                raise
            except Exception as exc:
                last_error = exc
                continue

        latency_ms = int((time.perf_counter() - start) * 1000)

        if parsed is None:
            raise StructuredOutputInvalid(
                details={
                    "agent": _AGENT_NAME,
                    "attempts": _MAX_PARSE_ATTEMPTS,
                    "last_error": repr(last_error) if last_error is not None else "",
                }
            )

        emit_agent_call_complete(
            _AGENT_NAME,
            model=cfg.OPENAI_MODEL_EXPERIMENT_PLANNER,
            prompt_hash=versions[_ROLE_FILE],
            prompt_tokens=parsed.usage.prompt_tokens,
            completion_tokens=parsed.usage.completion_tokens,
            latency_ms=latency_ms,
            verified_count=0,
            tier_0_drops=0,
            request_id=state.request_id,
        )
        return _strip_llm_verified_claims(parsed.parsed)


def _strip_llm_verified_claims(plan: ExperimentPlan) -> ExperimentPlan:
    """Zero `verified`/`verification_url`/`confidence` on every LLM-emitted row.

    The grounding pipeline (Step 30) is the only writer of `verified=True`.
    Anything the LLM placed in those fields is treated as untrusted and
    discarded here so a successful prompt-injection can never elevate
    confidence on a fabricated row.
    """

    return plan.model_copy(
        update={
            "references": [_strip_reference(r) for r in plan.references],
            "protocol": [_strip_protocol_step(s) for s in plan.protocol],
            "materials": [_strip_material(m) for m in plan.materials],
        }
    )


def _strip_reference(ref: Reference) -> Reference:
    return ref.model_copy(
        update={
            "verified": False,
            "verification_url": None,
            "confidence": "low",
        }
    )


def _strip_protocol_step(step: ProtocolStep) -> ProtocolStep:
    return step.model_copy(
        update={
            "verified": False,
            "verification_url": None,
            "confidence": "low",
        }
    )


def _strip_material(material: Material) -> Material:
    return material.model_copy(
        update={
            "verified": False,
            "verification_url": None,
            "confidence": "low",
        }
    )


def _format_user_payload(state: PipelineState) -> str:
    qc = state.qc_result
    if qc is None:
        qc_block = "(no literature-QC result was supplied — emit unverified placeholders)"
    else:
        rendered_refs = [
            {
                "title": ref.title,
                "url": str(ref.url),
                "doi": ref.doi,
                "tier": ref.tier.value,
                "why_relevant": ref.why_relevant,
                "verified": ref.verified,
            }
            for ref in qc.references
        ]
        qc_block = (
            f"novelty: {qc.novelty.value}\nconfidence: {qc.confidence}\nreferences: {rendered_refs}"
        )

    rendered_few_shots = list(state.few_shot_examples or [])
    return (
        "== HYPOTHESIS ==\n"
        f"{state.hypothesis}\n\n"
        "== LITERATURE QC ==\n"
        f"{qc_block}\n\n"
        "== PRIOR-CORRECTION FEW-SHOTS ==\n"
        f"{rendered_few_shots}"
    )
