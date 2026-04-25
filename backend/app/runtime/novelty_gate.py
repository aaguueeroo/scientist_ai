"""Pure novelty-gate decision function (Step 20).

The runtime orchestrator calls `decide()` with the novelty label
emitted by Agent 1 (Literature QC) and uses the result to choose
between continuing to Agent 2 + Agent 3 or short-circuiting back to the
client with the QC-only response.
"""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel

from app.schemas.literature_qc import NoveltyLabel


class Continue(BaseModel):
    """Continue the pipeline (Agent 2 + Agent 3)."""

    kind: Literal["continue"] = "continue"


class StopWithQC(BaseModel):
    """Short-circuit the pipeline; return QC result only."""

    kind: Literal["stop_with_qc"] = "stop_with_qc"


GateOutcome = Continue | StopWithQC


def decide(label: NoveltyLabel) -> GateOutcome:
    """Return the orchestrator's next action given a novelty label."""

    if label is NoveltyLabel.EXACT_MATCH:
        return StopWithQC()
    return Continue()
