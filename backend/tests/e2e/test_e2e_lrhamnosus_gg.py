"""Step 48 — E2E: Lactobacillus rhamnosus GG / mouse gut.

Drives `POST /generate-plan` with the *L. rhamnosus* GG colonization
hypothesis from the brief. The protocol contains 16S rRNA qPCR
quantification, so the returned plan must populate
`validation.miqe_compliance` (per the brief's MIQE-as-a-feature
requirement on Steps 32, 47, 48).

Runs offline against the deterministic fakes seeded in
`tests/e2e/conftest.py`.
"""

# mypy: disable-error-code="arg-type"

from __future__ import annotations

from collections.abc import AsyncIterator, Callable
from typing import Any

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.schemas.experiment_plan import ExperimentPlan
from app.schemas.literature_qc import NoveltyLabel
from tests.e2e.conftest import (
    HypothesisFixture,
    baseline_grounding,
    baseline_validation,
    make_material,
    make_protocol_step,
    make_reference,
)

LR_HYPOTHESIS = (
    "Daily oral gavage of Lactobacillus rhamnosus GG (ATCC 53103) to C57BL/6 mice "
    "for 14 days increases relative abundance of LGG in cecal contents by ≥ 1 log10 "
    "copies per gram compared with vehicle controls, measured by 16S rRNA qPCR."
)

LR_DOI_PRIMARY = "10.1128/AEM.02676-09"
LR_DOI_SECONDARY = "10.1038/ismej.2010.118"

LR_REF_PRIMARY_URL = "https://journals.asm.org/doi/10.1128/AEM.02676-09"
LR_REF_SECONDARY_URL = "https://www.nature.com/articles/ismej2010118"


def _build_lr_plan() -> ExperimentPlan:
    return ExperimentPlan(
        plan_id="plan-e2e-lr-001",
        hypothesis=LR_HYPOTHESIS,
        novelty=NoveltyLabel.SIMILAR_WORK_EXISTS,
        references=[
            make_reference(
                title="Quantitative 16S rRNA qPCR for LGG in mouse gut",
                url=LR_REF_PRIMARY_URL,
                doi=LR_DOI_PRIMARY,
                why_relevant=(
                    "Establishes the strain-specific 16S qPCR primers and "
                    "absolute-quantification workflow for LGG colonization."
                ),
            ),
            make_reference(
                title="LGG colonization dynamics in C57BL/6 mice",
                url=LR_REF_SECONDARY_URL,
                doi=LR_DOI_SECONDARY,
                why_relevant=(
                    "Reports the 14-day oral-gavage time course used as the "
                    "baseline for the proposed dosing schedule."
                ),
            ),
        ],
        protocol=[
            make_protocol_step(
                order=1,
                technique="Oral gavage of LGG suspension (1e9 CFU / day)",
                source_url=LR_REF_SECONDARY_URL,
            ),
            make_protocol_step(
                order=2,
                technique="Cecal-content collection at day 14",
                source_url=LR_REF_PRIMARY_URL,
            ),
            make_protocol_step(
                order=3,
                technique="DNA extraction (PowerSoil Pro)",
                source_url=LR_REF_PRIMARY_URL,
            ),
            make_protocol_step(
                order=4,
                technique="16S rRNA qPCR with strain-specific primers",
                description=(
                    "Absolute-quantification qPCR using LGG-specific 16S primers; "
                    "standard curve from purified amplicon dilutions."
                ),
                source_url=LR_REF_PRIMARY_URL,
            ),
        ],
        materials=[
            make_material(
                reagent="Lactobacillus rhamnosus GG (ATCC 53103)",
                vendor="Sigma-Aldrich",
                sku="53103",
                notes="grown in MRS broth, washed in PBS before gavage",
            ),
            make_material(
                reagent="QIAamp PowerSoil Pro DNA Kit",
                vendor="Sigma-Aldrich",
                sku="47016",
            ),
            make_material(
                reagent="PowerUp SYBR Green qPCR Master Mix",
                vendor="Thermo Fisher",
                sku="A25742",
            ),
        ],
        validation=baseline_validation(),
        grounding_summary=baseline_grounding(),
    )


LR_FIXTURE = HypothesisFixture(
    hypothesis=LR_HYPOTHESIS,
    keyword_summary="Lactobacillus rhamnosus GG colonization C57BL/6 16S qPCR",
    references=[
        make_reference(
            title="Quantitative 16S rRNA qPCR for LGG in mouse gut",
            url=LR_REF_PRIMARY_URL,
            doi=LR_DOI_PRIMARY,
            why_relevant=(
                "Establishes the strain-specific 16S qPCR primers for LGG."
            ),
        ),
        make_reference(
            title="LGG colonization dynamics in C57BL/6 mice",
            url=LR_REF_SECONDARY_URL,
            doi=LR_DOI_SECONDARY,
            why_relevant="Baseline 14-day oral-gavage time course for LGG.",
        ),
    ],
    plan=_build_lr_plan(),
    sku_resolutions={
        "53103": (
            "Sigma-Aldrich",
            "https://www.sigmaaldrich.com/US/en/product/sigma/53103",
        ),
        "47016": (
            "Sigma-Aldrich",
            "https://www.sigmaaldrich.com/US/en/product/sigma/47016",
        ),
        "A25742": (
            "Thermo Fisher",
            "https://www.thermofisher.com/order/catalog/product/A25742",
        ),
    },
)


async def _post_generate_plan(app: FastAPI) -> dict[str, Any]:
    transport = ASGITransport(app=app, raise_app_exceptions=False)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            "/generate-plan",
            json={"hypothesis": LR_HYPOTHESIS},
        )
    assert response.status_code == 200, response.text
    body: dict[str, Any] = response.json()
    return body


@pytest.mark.asyncio
async def test_e2e_lrhamnosus_returns_plan_with_verified_references(
    e2e_app_factory: Callable[
        [HypothesisFixture],
        AsyncIterator[FastAPI],
    ],
) -> None:
    async for app in e2e_app_factory(LR_FIXTURE):
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
async def test_e2e_lrhamnosus_plan_populates_miqe_compliance_block(
    e2e_app_factory: Callable[
        [HypothesisFixture],
        AsyncIterator[FastAPI],
    ],
) -> None:
    async for app in e2e_app_factory(LR_FIXTURE):
        body = await _post_generate_plan(app)

    plan = body["plan"]
    miqe = plan["validation"]["miqe_compliance"]
    assert miqe is not None, (
        "L. rhamnosus GG protocol contains 16S qPCR -> "
        "miqe_compliance must be populated"
    )
    for category in (
        "sample",
        "nucleic_acid_extraction",
        "qpcr_target_information",
        "qpcr_oligonucleotides",
        "qpcr_protocol",
    ):
        assert category in miqe, f"missing MIQE category {category}"
