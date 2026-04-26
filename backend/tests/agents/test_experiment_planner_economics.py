# mypy: disable-error-code="arg-type"

from __future__ import annotations

from app.agents.experiment_planner_economics import (
    apply_material_driven_budget_autofix,
    economics_violations,
    format_repair_user_message,
)
from app.schemas.experiment_plan import (
    Budget,
    BudgetLineItem,
    ExperimentPlan,
    GroundingSummary,
    Material,
    ValidationPlan,
)
from app.schemas.literature_qc import NoveltyLabel, SourceTier


def _minimal_plan(
    *,
    materials: list[Material],
    items: list[BudgetLineItem],
    total: float,
) -> ExperimentPlan:
    return ExperimentPlan(
        plan_id="plan-eco",
        hypothesis="Test hypothesis for economics.",
        novelty=NoveltyLabel.SIMILAR_WORK_EXISTS,
        materials=materials,
        budget=Budget(items=items, total_usd=total),
        validation=ValidationPlan(),
        grounding_summary=GroundingSummary(verified_count=0, unverified_count=0),
    )


def test_economics_violations_empty_when_aligned() -> None:
    m = [
        Material(
            reagent="A",
            vendor="V",
            sku="1",
            qty=2.0,
            qty_unit="g",
            unit_cost_usd=5.0,
            tier=SourceTier.TIER_1_PEER_REVIEWED,
        ),
        Material(
            reagent="B",
            vendor="V",
            sku="2",
            qty=1.0,
            qty_unit="each",
            unit_cost_usd=40.0,
            tier=SourceTier.TIER_1_PEER_REVIEWED,
        ),
    ]
    p = _minimal_plan(
        materials=m,
        items=[
            BudgetLineItem(label="A (2 g @ $5/g)", cost_usd=10.0),
            BudgetLineItem(label="B (1 each)", cost_usd=40.0),
        ],
        total=50.0,
    )
    assert economics_violations(p) == []


def test_economics_violations_count_mismatch() -> None:
    p = _minimal_plan(
        materials=[
            Material(
                reagent="A",
                vendor="V",
                sku="1",
                qty=1.0,
                qty_unit="each",
                unit_cost_usd=10.0,
                tier=SourceTier.TIER_1_PEER_REVIEWED,
            ),
        ],
        items=[BudgetLineItem(label="A", cost_usd=5.0), BudgetLineItem(label="B", cost_usd=5.0)],
        total=10.0,
    )
    v = economics_violations(p)
    assert any("1 material" in x and "2 budget" in x for x in v)


def test_apply_material_driven_budget_autofix_snaps_to_qty_times_unit() -> None:
    p = _minimal_plan(
        materials=[
            Material(
                reagent="Sucrose",
                vendor="S",
                sku="S7",
                qty=25.0,
                qty_unit="g",
                unit_cost_usd=1.2,
                tier=SourceTier.TIER_1_PEER_REVIEWED,
            ),
        ],
        items=[BudgetLineItem(label="Sucrose (wrong)", cost_usd=30.0)],
        total=99.0,
    )
    fixed = apply_material_driven_budget_autofix(p)
    assert fixed.budget.items[0].cost_usd == 30.0
    assert fixed.budget.total_usd == 30.0


def test_format_repair_user_message_contains_violations() -> None:
    p = _minimal_plan(
        materials=[
            Material(
                reagent="X",
                vendor="V",
                sku="1",
                qty=1.0,
                qty_unit="g",
                unit_cost_usd=1.0,
                tier=SourceTier.TIER_1_PEER_REVIEWED,
            ),
        ],
        items=[BudgetLineItem(label="X", cost_usd=2.0)],
        total=1.0,
    )
    v = economics_violations(p)
    assert v
    msg = format_repair_user_message(p, v)
    assert "VALIDATION ERRORS" in msg
    assert "DRAFT" in msg
