"""Step 47 — E2E: CRP paper-based biosensor.

Drives `POST /literature-review` and `POST /experiment-plan` with the CRP biosensor hypothesis from
the
brief. The protocol contains a qPCR clone-confirmation step, so the
returned plan must populate `validation.miqe_compliance`.

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
    baseline_grounding,
    baseline_validation,
    make_material,
    make_protocol_step,
    make_reference,
    post_literature_then_experiment_plan_e2e,
)

CRP_HYPOTHESIS = (
    "A paper-based electrochemical biosensor can detect C-reactive protein (CRP) "
    "in unprocessed whole blood within 10 minutes at the < 1 mg/L sensitivity needed "
    "for sepsis screening."
)

CRP_DOI_PRIMARY = "10.1016/j.bios.2021.113555"
CRP_DOI_SECONDARY = "10.1021/acs.analchem.0c03842"

CRP_REF_PRIMARY_URL = "https://www.sciencedirect.com/science/article/pii/S0956566321006333"
CRP_REF_SECONDARY_URL = "https://pubs.acs.org/doi/10.1021/acs.analchem.0c03842"


def _build_crp_plan() -> ExperimentPlan:
    return ExperimentPlan(
        plan_id="plan-e2e-crp-001",
        hypothesis=CRP_HYPOTHESIS,
        novelty=NoveltyLabel.SIMILAR_WORK_EXISTS,
        references=[
            make_reference(
                title="Paper-based electrochemical biosensors for CRP",
                url=CRP_REF_PRIMARY_URL,
                doi=CRP_DOI_PRIMARY,
                why_relevant=(
                    "Direct prior art on paper-based amperometric CRP detection in whole blood."
                ),
            ),
            make_reference(
                title="Whole-blood CRP electrochemical assay",
                url=CRP_REF_SECONDARY_URL,
                doi=CRP_DOI_SECONDARY,
                why_relevant="Establishes the < 1 mg/L sensitivity benchmark.",
            ),
        ],
        protocol=[
            make_protocol_step(
                order=1,
                technique="Antibody immobilization on cellulose paper",
                source_url=CRP_REF_PRIMARY_URL,
            ),
            make_protocol_step(
                order=2,
                technique="qPCR confirmation of antibody clone identity",
                description=(
                    "RT-qPCR on the antibody-encoding hybridoma lot to verify "
                    "VH/VL transcript identity before reagent QC."
                ),
                source_url=CRP_REF_PRIMARY_URL,
            ),
            make_protocol_step(
                order=3,
                technique="Electrochemical readout against CRP standards",
                source_url=CRP_REF_SECONDARY_URL,
            ),
        ],
        materials=[
            make_material(
                reagent="Anti-human CRP monoclonal antibody",
                vendor="Sigma-Aldrich",
                sku="C1688",
                notes="capture antibody, use 5 ug/mL coating buffer",
            ),
            make_material(
                reagent="Whatman cellulose chromatography paper",
                vendor="Sigma-Aldrich",
                sku="WHA1001917",
            ),
            make_material(
                reagent="C-reactive protein assay buffer",
                vendor="Thermo Fisher",
                sku="34577",
            ),
        ],
        validation=baseline_validation(),
        grounding_summary=baseline_grounding(),
    )


CRP_FIXTURE = HypothesisFixture(
    hypothesis=CRP_HYPOTHESIS,
    keyword_summary="paper-based electrochemical CRP biosensor whole blood sepsis",
    references=[
        make_reference(
            title="Paper-based electrochemical biosensors for CRP",
            url=CRP_REF_PRIMARY_URL,
            doi=CRP_DOI_PRIMARY,
            why_relevant="Direct prior art on paper-based CRP detection.",
        ),
        make_reference(
            title="Whole-blood CRP electrochemical assay",
            url=CRP_REF_SECONDARY_URL,
            doi=CRP_DOI_SECONDARY,
            why_relevant="Establishes the < 1 mg/L sensitivity benchmark.",
        ),
    ],
    plan=_build_crp_plan(),
    sku_resolutions={
        "C1688": (
            "Sigma-Aldrich",
            "https://www.sigmaaldrich.com/US/en/product/sigma/c1688",
        ),
        "WHA1001917": (
            "Sigma-Aldrich",
            "https://www.sigmaaldrich.com/US/en/product/whatman/wha1001917",
        ),
        "34577": (
            "Thermo Fisher",
            "https://www.thermofisher.com/order/catalog/product/34577",
        ),
    },
)


async def _post_generate_plan(app: FastAPI) -> dict[str, Any]:
    return await post_literature_then_experiment_plan_e2e(app, hypothesis=CRP_HYPOTHESIS)


@pytest.mark.asyncio
async def test_e2e_crp_returns_plan_with_verified_references(
    e2e_app_factory: Callable[
        [HypothesisFixture],
        AsyncIterator[FastAPI],
    ],
) -> None:
    async for app in e2e_app_factory(CRP_FIXTURE):
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
async def test_e2e_crp_plan_populates_miqe_compliance_block(
    e2e_app_factory: Callable[
        [HypothesisFixture],
        AsyncIterator[FastAPI],
    ],
) -> None:
    async for app in e2e_app_factory(CRP_FIXTURE):
        body = await _post_generate_plan(app)

    plan = body["plan"]
    miqe = plan["validation"]["miqe_compliance"]
    assert miqe is not None, (
        "CRP biosensor protocol contains qPCR -> miqe_compliance must be populated"
    )
    for category in (
        "sample",
        "nucleic_acid_extraction",
        "reverse_transcription",
        "qpcr_target_information",
        "qpcr_oligonucleotides",
        "qpcr_protocol",
        "qpcr_validation",
        "data_analysis",
        "methodological_details",
    ):
        assert category in miqe, f"missing MIQE category {category}"


@pytest.mark.asyncio
async def test_e2e_crp_response_carries_prompt_versions(
    e2e_app_factory: Callable[
        [HypothesisFixture],
        AsyncIterator[FastAPI],
    ],
) -> None:
    async for app in e2e_app_factory(CRP_FIXTURE):
        body = await _post_generate_plan(app)

    versions = body.get("prompt_versions")
    assert isinstance(versions, dict), "prompt_versions must be a dict"
    assert set(versions.keys()) == {
        "literature_qc.md",
        "feedback_relevance.md",
        "experiment_planner.md",
    }
    assert all(isinstance(v, str) and len(v) >= 16 for v in versions.values()), (
        "Every prompt-version value must be a non-empty hex hash"
    )
