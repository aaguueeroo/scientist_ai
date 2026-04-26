"""Economics checks and alignment for the experiment plan (Agent 3).

`unit_cost_usd` is defined as the estimated USD for **one** unit of
`qty_unit` (e.g. per g, per mL, per vial, per each). The **line subtotal**
is ``qty * unit_cost_usd`` and must match the paired budget line and roll
up to `budget.total_usd`.
"""

from __future__ import annotations

import json
from math import isfinite

from app.schemas.experiment_plan import BudgetLineItem, ExperimentPlan, Material

# Lab-estimate slush: rounding + rough catalog numbers.
_USD_ABSOLUTE_EPS = 0.5
# Relative slush for larger lines (avoids whack-a-mole on 37.4 vs 37.0).
_USD_RELATIVE_EPS = 0.02


def _close_sum(a: float, b: float) -> bool:
    if not isfinite(a) or not isfinite(b):
        return False
    tol = _USD_ABSOLUTE_EPS + _USD_RELATIVE_EPS * max(abs(a), abs(b), 1.0)
    return abs(a - b) <= tol


def _line_subtotal(m: Material) -> float:
    return m.qty * m.unit_cost_usd


def economics_violations(plan: ExperimentPlan) -> list[str]:
    """Return human-readable issues; empty if checks pass."""
    out: list[str] = []
    b = plan.budget
    items = b.items
    n_m = len(plan.materials)
    n_b = len(items)
    if n_m != n_b:
        out.append(
            f"materials and budget line counts must match (one budget line per material, same "
            f"order): got {n_m} material(s) and {n_b} budget line(s)."
        )
    sum_lines = sum(li.cost_usd for li in items)
    if not _close_sum(float(b.total_usd), sum_lines):
        out.append(
            f"budget.total_usd is {b.total_usd} but the sum of budget.items[].cost_usd is "
            f"{sum_lines} (tolerance: absolute {_USD_ABSOLUTE_EPS} + 2% of magnitude)."
        )
    if n_m == n_b:
        for i, (mat, line) in enumerate(zip(plan.materials, items, strict=True)):
            sub = _line_subtotal(mat)
            if not _close_sum(sub, line.cost_usd):
                out.append(
                    f"row {i + 1} ({mat.reagent!r}): subtotal qty*unit_cost_usd = "
                    f"{mat.qty} * {mat.unit_cost_usd} = {sub}, but budget line cost_usd = "
                    f"{line.cost_usd}. use unit_cost_usd as price per one {mat.qty_unit!r}."
                )
        mat_sum = sum(_line_subtotal(m) for m in plan.materials)
        if not _close_sum(float(b.total_usd), mat_sum):
            out.append(
                f"budget.total_usd ({b.total_usd}) does not match sum of material subtotals "
                f"({mat_sum}) after line-by-line check."
            )
    return out


def apply_material_driven_budget_autofix(plan: ExperimentPlan) -> ExperimentPlan:
    """When row counts match, snap `budget` numbers to `materials` math.

    Labels are preserved. Call after model repair (or on best-effort last pass)
    to guarantee internal arithmetic consistency.
    """
    mlist = plan.materials
    if len(mlist) != len(plan.budget.items):
        return plan
    new_items: list[BudgetLineItem] = []
    for mat, li in zip(mlist, plan.budget.items, strict=True):
        sub = round(_line_subtotal(mat), 2)
        new_items.append(li.model_copy(update={"cost_usd": sub}))
    total = round(sum(li.cost_usd for li in new_items), 2)
    new_budget = plan.budget.model_copy(update={"items": new_items, "total_usd": total})
    return plan.model_copy(update={"budget": new_budget})


def format_repair_user_message(
    plan: ExperimentPlan, violations: list[str], *, max_json_chars: int = 40_000
) -> str:
    """User message for a follow-up parse: draft JSON + what failed."""
    payload = plan.model_dump(mode="json")
    blob = json.dumps(payload, ensure_ascii=False, indent=2)
    if len(blob) > max_json_chars:
        blob = blob[:max_json_chars] + "\n… [truncated for length]\n"
    v_block = "\n".join(f"- {v}" for v in violations)
    return (
        "The previous `ExperimentPlan` failed internal economics validation. You must return "
        "a **full replacement** `ExperimentPlan` in the same schema, fixing all issues. "
        "Do not return partial objects.\n\n"
        "Rules to satisfy:\n"
        "- `unit_cost_usd` = USD for **one** unit of `qty_unit` (e.g. per g, mL, vial, each), "
        "**not** the line total and **not** the pack price unless `qty=1` and the unit is the "
        "pack.\n"
        "- For each material row, **line subtotal** = `qty * unit_cost_usd` (rounded in your "
        "head to ~2 decimal places; server checks within tolerance).\n"
        "- `budget` must have **one line per material** in the **same order**; "
        "`items[i].cost_usd` = subtotal for `materials[i]`.\n"
        "- `budget.total_usd` = sum of `items[].cost_usd` (USD).\n"
        "- Keep hypothesis, protocol, references, and semantics; correct numbers and structure "
        "only where needed for consistency.\n\n"
        f"--- VALIDATION ERRORS ---\n{v_block}\n\n"
        f"--- DRAFT TO FIX (JSON) ---\n{blob}\n"
    )
