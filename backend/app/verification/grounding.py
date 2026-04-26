"""Grounding pipeline for `ExperimentPlan`.

`apply_resolvers` runs the citation resolver over every reference (and
every protocol step's source DOI/URL where present), runs the catalog
resolver over every material, and returns a copy of the plan with
`verified` / `verification_url` / `confidence` populated by code (never
by the LLM). The aggregate `grounding_summary` is rebuilt from the
result, including a Tier-0 drop counter that the orchestrator reports
in its per-request log line.
"""

from __future__ import annotations

from app.schemas.experiment_plan import (
    ExperimentPlan,
    GroundingSummary,
    Material,
    ProtocolStep,
)
from app.schemas.literature_qc import Reference
from app.verification.catalog_resolver import AbstractCatalogResolver
from app.verification.citation_resolver import (
    AbstractCitationResolver,
    CitationOutcome,
)


async def apply_resolvers(
    plan: ExperimentPlan,
    *,
    citation_resolver: AbstractCitationResolver,
    catalog_resolver: AbstractCatalogResolver,
) -> ExperimentPlan:
    """Run resolvers over every reference / protocol step / material.

    Tier-0 references are dropped (and counted in `tier_0_drops`).
    Unresolved references stay in the plan with `verified=False,
    confidence="low"` so a downstream reviewer can see what the LLM
    proposed and why it was not honored.
    """

    grounded_refs: list[Reference] = []
    tier_0_drops = 0
    for ref in plan.references:
        outcome = await citation_resolver.resolve(ref)
        if outcome.tier_0_drop:
            tier_0_drops += 1
            continue
        grounded_refs.append(_grounded_reference(ref, outcome))

    grounded_steps: list[ProtocolStep] = []
    for step in plan.protocol:
        step_ref = _step_reference_or_none(step)
        if step_ref is None:
            grounded_steps.append(_unverified_step(step))
            continue
        outcome = await citation_resolver.resolve(step_ref)
        if outcome.tier_0_drop:
            tier_0_drops += 1
            grounded_steps.append(_unverified_step(step))
            continue
        if outcome.reference is not None and outcome.reference.verified:
            grounded_steps.append(
                step.model_copy(
                    update={
                        "verified": True,
                        "verification_url": outcome.reference.verification_url,
                        "confidence": "high",
                        "tier": outcome.reference.tier,
                    }
                )
            )
        else:
            grounded_steps.append(_unverified_step(step))

    grounded_materials: list[Material] = []
    for material in plan.materials:
        grounded_materials.append(await catalog_resolver.resolve(material))

    verified_refs = sum(1 for r in grounded_refs if r.verified)
    unverified_refs = sum(1 for r in grounded_refs if not r.verified)
    verified_steps = sum(1 for s in grounded_steps if s.verified)
    unverified_steps = sum(1 for s in grounded_steps if not s.verified)
    verified_mats = sum(1 for m in grounded_materials if m.verified)
    unverified_mats = sum(1 for m in grounded_materials if not m.verified)

    summary = GroundingSummary(
        verified_count=verified_refs + verified_steps + verified_mats,
        unverified_count=unverified_refs + unverified_steps + unverified_mats,
        tier_0_drops=tier_0_drops,
    )

    return plan.model_copy(
        update={
            "references": grounded_refs,
            "protocol": grounded_steps,
            "materials": grounded_materials,
            "grounding_summary": summary,
        }
    )


def _grounded_reference(ref: Reference, outcome: CitationOutcome) -> Reference:
    if outcome.reference is not None and outcome.reference.verified:
        return outcome.reference
    return ref.model_copy(
        update={
            "verified": False,
            "verification_url": None,
            "confidence": "low",
        }
    )


def _unverified_step(step: ProtocolStep) -> ProtocolStep:
    return step.model_copy(
        update={
            "verified": False,
            "verification_url": None,
            "confidence": "low",
        }
    )


_GROUNDING_ALL_UNVERIFIED_CAVEAT = (
    "Automated verification did not confirm any citation link or product catalog match. "
    "Treat references, protocol sources, and materials as unverified; validate before use."
)


def apply_grounding_caveat_if_all_unverified(plan: ExperimentPlan) -> ExperimentPlan:
    """If every grounding slot failed verification, attach a user-visible caveat.

    The plan is still returned (HTTP 200); rows remain marked unverified. When at
    least one reference, step, or material verifies, no caveat is added.
    """

    s = plan.grounding_summary
    if s.verified_count > 0 or s.unverified_count == 0:
        return plan
    return plan.model_copy(
        update={
            "grounding_summary": s.model_copy(
                update={"grounding_caveat": _GROUNDING_ALL_UNVERIFIED_CAVEAT}
            )
        }
    )


def _step_reference_or_none(step: ProtocolStep) -> Reference | None:
    """Treat a `ProtocolStep` with a `source_url` (or DOI) as a citable reference."""

    if step.source_url is None and step.source_doi is None:
        return None
    url = (
        str(step.source_url)
        if step.source_url is not None
        else f"https://doi.org/{step.source_doi}"
    )
    return Reference(
        title=step.technique,
        url=url,
        doi=step.source_doi,
        why_relevant=step.description or step.technique,
        tier=step.tier,
    )
