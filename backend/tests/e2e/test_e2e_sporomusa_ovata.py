"""Step 50 — E2E: Sporomusa ovata CO2 fixation.

Drives `POST /literature-review` + `POST /experiment-plan` with the *Sporomusa ovata* CO2-fixation
hypothesis from the brief. The protocol is electrochemical and contains
no qPCR; the returned plan must therefore leave
`validation.miqe_compliance` as `None` (the brief calls this out as a
distinguishing case in Steps 32 and 50).

Runs offline against the deterministic fakes seeded in
`tests/e2e/conftest.py`.
"""

# mypy: disable-error-code="arg-type"

from __future__ import annotations

from collections.abc import AsyncIterator, Callable
from typing import Any

import pytest
from fastapi import FastAPI

from app.schemas.experiment_plan import ExperimentPlan
from app.schemas.literature_qc import NoveltyLabel
from tests.e2e.conftest import (
    HypothesisFixture,
    baseline_budget,
    baseline_grounding,
    baseline_validation,
    make_material,
    make_protocol_step,
    make_reference,
    post_literature_then_experiment_plan_e2e,
)

SO_HYPOTHESIS = (
    "Sporomusa ovata grown on a graphite cathode at -400 mV vs SHE fixes CO2 into "
    "acetate at a Coulombic efficiency above 80%, sustained over a 7-day batch run."
)

SO_DOI_PRIMARY = "10.1128/mBio.00103-10"
SO_DOI_SECONDARY = "10.1126/science.aam5731"

SO_REF_PRIMARY_URL = "https://journals.asm.org/doi/10.1128/mBio.00103-10"
SO_REF_SECONDARY_URL = "https://www.science.org/doi/10.1126/science.aam5731"


def _build_sporomusa_plan() -> ExperimentPlan:
    return ExperimentPlan(
        plan_id="plan-e2e-sporomusa-001",
        hypothesis=SO_HYPOTHESIS,
        novelty=NoveltyLabel.SIMILAR_WORK_EXISTS,
        references=[
            make_reference(
                title="Direct electron uptake by Sporomusa ovata",
                url=SO_REF_PRIMARY_URL,
                doi=SO_DOI_PRIMARY,
                why_relevant=(
                    "First report of cathodic acetate production by S. ovata; "
                    "establishes the -400 mV vs SHE working point."
                ),
            ),
            make_reference(
                title="Microbial electrosynthesis at scale",
                url=SO_REF_SECONDARY_URL,
                doi=SO_DOI_SECONDARY,
                why_relevant=(
                    "Reports the Coulombic-efficiency benchmarks for "
                    "long-duration acetogenic electrosynthesis."
                ),
            ),
        ],
        protocol=[
            make_protocol_step(
                order=1,
                technique="Prepare two-chamber bioelectrochemical cell with graphite cathode",
                source_url=SO_REF_PRIMARY_URL,
            ),
            make_protocol_step(
                order=2,
                technique="Inoculate cathode chamber with S. ovata under N2/CO2",
                source_url=SO_REF_PRIMARY_URL,
            ),
            make_protocol_step(
                order=3,
                technique="Apply -400 mV vs SHE for 7 days under chronoamperometry",
                source_url=SO_REF_SECONDARY_URL,
            ),
            make_protocol_step(
                order=4,
                technique="HPLC quantification of acetate in catholyte",
                source_url=SO_REF_SECONDARY_URL,
            ),
        ],
        materials=[
            make_material(
                reagent="Graphite stick electrode (3 mm)",
                vendor="Sigma-Aldrich",
                sku="496545",
                notes="cathode working electrode",
            ),
            make_material(
                reagent="Sodium bicarbonate, anhydrous",
                vendor="Sigma-Aldrich",
                sku="S5761",
            ),
            make_material(
                reagent="Anaerobic culture medium DSMZ 311",
                vendor="Thermo Fisher",
                sku="DSMZ-311-MED",
            ),
        ],
        budget=baseline_budget(label="Sporomusa electrochem study (planning est.)", total=600.0),
        validation=baseline_validation(),
        grounding_summary=baseline_grounding(),
    )


SPOROMUSA_FIXTURE = HypothesisFixture(
    hypothesis=SO_HYPOTHESIS,
    keyword_summary="Sporomusa ovata cathode CO2 fixation acetate electrosynthesis",
    references=[
        make_reference(
            title="Direct electron uptake by Sporomusa ovata",
            url=SO_REF_PRIMARY_URL,
            doi=SO_DOI_PRIMARY,
            why_relevant="Cathodic acetate production by S. ovata at -400 mV.",
        ),
        make_reference(
            title="Microbial electrosynthesis at scale",
            url=SO_REF_SECONDARY_URL,
            doi=SO_DOI_SECONDARY,
            why_relevant="Coulombic-efficiency benchmarks for electrosynthesis.",
        ),
    ],
    plan=_build_sporomusa_plan(),
    sku_resolutions={
        "496545": (
            "Sigma-Aldrich",
            "https://www.sigmaaldrich.com/US/en/product/sigma/496545",
        ),
        "S5761": (
            "Sigma-Aldrich",
            "https://www.sigmaaldrich.com/US/en/product/sigma/S5761",
        ),
        "DSMZ-311-MED": (
            "Thermo Fisher",
            "https://www.thermofisher.com/order/catalog/product/DSMZ-311-MED",
        ),
    },
)


async def _post_generate_plan(app: FastAPI) -> dict[str, Any]:
    return await post_literature_then_experiment_plan_e2e(app, hypothesis=SO_HYPOTHESIS)


@pytest.mark.asyncio
async def test_e2e_sporomusa_returns_plan_with_verified_references(
    e2e_app_factory: Callable[
        [HypothesisFixture],
        AsyncIterator[FastAPI],
    ],
) -> None:
    async for app in e2e_app_factory(SPOROMUSA_FIXTURE):
        body = await _post_generate_plan(app)

    plan = body["plan"]
    assert plan is not None
    assert plan["references"], "Plan must carry at least one reference"
    assert all(ref["verified"] is True for ref in plan["references"]), (
        f"Every reference must be verified; got {plan['references']}"
    )
    assert all(ref["verification_url"] for ref in plan["references"])
    assert all(mat["verified"] is True for mat in plan["materials"])


@pytest.mark.asyncio
async def test_e2e_sporomusa_plan_miqe_compliance_is_none(
    e2e_app_factory: Callable[
        [HypothesisFixture],
        AsyncIterator[FastAPI],
    ],
) -> None:
    async for app in e2e_app_factory(SPOROMUSA_FIXTURE):
        body = await _post_generate_plan(app)

    plan = body["plan"]
    miqe = plan["validation"]["miqe_compliance"]
    assert miqe is None, (
        "Sporomusa ovata electrosynthesis protocol contains no qPCR; miqe_compliance must be None"
    )
