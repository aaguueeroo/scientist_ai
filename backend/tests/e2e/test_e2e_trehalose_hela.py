"""Step 49 — E2E: Trehalose vs sucrose cryopreservation of HeLa cells.

Drives `POST /generate-plan` with the trehalose hypothesis from the
brief. The plan asserts the *actual* MIQE outcome rather than a fixed
expectation: this protocol does not run qPCR, so MIQE compliance must be
`None` for the canned plan returned by the fake planner.

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

TREHALOSE_HYPOTHESIS = (
    "Cryopreservation of HeLa cells in DMEM supplemented with 10% trehalose yields "
    "a significantly higher post-thaw viability than equimolar sucrose, measured by "
    "trypan-blue exclusion 24 hours after thaw."
)

TREHALOSE_DOI_PRIMARY = "10.1006/cryo.2001.2316"
TREHALOSE_DOI_SECONDARY = "10.1016/j.cryobiol.2017.04.001"

TREHALOSE_REF_PRIMARY_URL = "https://www.sciencedirect.com/science/article/pii/S0011224001923161"
TREHALOSE_REF_SECONDARY_URL = "https://www.sciencedirect.com/science/article/pii/S0011224017301402"


def _build_trehalose_plan() -> ExperimentPlan:
    return ExperimentPlan(
        plan_id="plan-e2e-trehalose-001",
        hypothesis=TREHALOSE_HYPOTHESIS,
        novelty=NoveltyLabel.SIMILAR_WORK_EXISTS,
        references=[
            make_reference(
                title="Trehalose as a cryoprotectant for mammalian cells",
                url=TREHALOSE_REF_PRIMARY_URL,
                doi=TREHALOSE_DOI_PRIMARY,
                why_relevant=(
                    "Foundational comparison of trehalose vs sucrose for "
                    "post-thaw viability of mammalian cell lines."
                ),
            ),
            make_reference(
                title="Disaccharide cryoprotection of HeLa cells",
                url=TREHALOSE_REF_SECONDARY_URL,
                doi=TREHALOSE_DOI_SECONDARY,
                why_relevant=(
                    "Reports the trypan-blue 24-hour viability protocol used as the readout."
                ),
            ),
        ],
        protocol=[
            make_protocol_step(
                order=1,
                technique="Prepare trehalose- and sucrose-DMEM cryoprotectant",
                source_url=TREHALOSE_REF_PRIMARY_URL,
            ),
            make_protocol_step(
                order=2,
                technique="Controlled-rate freezing of HeLa aliquots",
                source_url=TREHALOSE_REF_SECONDARY_URL,
            ),
            make_protocol_step(
                order=3,
                technique="Thaw and 24-hour recovery in fresh medium",
                source_url=TREHALOSE_REF_SECONDARY_URL,
            ),
            make_protocol_step(
                order=4,
                technique="Trypan-blue exclusion viability count",
                source_url=TREHALOSE_REF_SECONDARY_URL,
            ),
        ],
        materials=[
            make_material(
                reagent="D-(+)-Trehalose dihydrate",
                vendor="Sigma-Aldrich",
                sku="T9531",
                notes="cell-culture grade, prepare 10% w/v in DMEM",
            ),
            make_material(
                reagent="Sucrose",
                vendor="Sigma-Aldrich",
                sku="S0389",
                notes="equimolar control",
            ),
            make_material(
                reagent="DMEM, high glucose",
                vendor="Thermo Fisher",
                sku="11965092",
            ),
        ],
        validation=baseline_validation(),
        grounding_summary=baseline_grounding(),
    )


TREHALOSE_FIXTURE = HypothesisFixture(
    hypothesis=TREHALOSE_HYPOTHESIS,
    keyword_summary="trehalose sucrose HeLa cryopreservation post-thaw viability",
    references=[
        make_reference(
            title="Trehalose as a cryoprotectant for mammalian cells",
            url=TREHALOSE_REF_PRIMARY_URL,
            doi=TREHALOSE_DOI_PRIMARY,
            why_relevant=(
                "Foundational comparison of trehalose vs sucrose for post-thaw viability."
            ),
        ),
        make_reference(
            title="Disaccharide cryoprotection of HeLa cells",
            url=TREHALOSE_REF_SECONDARY_URL,
            doi=TREHALOSE_DOI_SECONDARY,
            why_relevant="Trypan-blue 24-hour viability protocol.",
        ),
    ],
    plan=_build_trehalose_plan(),
    sku_resolutions={
        "T9531": (
            "Sigma-Aldrich",
            "https://www.sigmaaldrich.com/US/en/product/sigma/T9531",
        ),
        "S0389": (
            "Sigma-Aldrich",
            "https://www.sigmaaldrich.com/US/en/product/sigma/S0389",
        ),
        "11965092": (
            "Thermo Fisher",
            "https://www.thermofisher.com/order/catalog/product/11965092",
        ),
    },
)


async def _post_generate_plan(app: FastAPI) -> dict[str, Any]:
    transport = ASGITransport(app=app, raise_app_exceptions=False)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            "/generate-plan",
            json={"hypothesis": TREHALOSE_HYPOTHESIS},
        )
    assert response.status_code == 200, response.text
    body: dict[str, Any] = response.json()
    return body


@pytest.mark.asyncio
async def test_e2e_trehalose_returns_plan_with_verified_references(
    e2e_app_factory: Callable[
        [HypothesisFixture],
        AsyncIterator[FastAPI],
    ],
) -> None:
    async for app in e2e_app_factory(TREHALOSE_FIXTURE):
        body = await _post_generate_plan(app)

    plan = body["plan"]
    assert plan is not None
    assert plan["references"], "Plan must carry at least one reference"
    assert all(ref["verified"] is True for ref in plan["references"]), (
        f"Every reference must be verified; got {plan['references']}"
    )
    assert all(ref["verification_url"] for ref in plan["references"])
    assert all(mat["verified"] is True for mat in plan["materials"])

    miqe = plan["validation"]["miqe_compliance"]
    assert miqe is None, "Trehalose protocol does not include qPCR; miqe_compliance must be None"
