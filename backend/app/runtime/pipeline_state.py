"""Per-request runtime pipeline state.

`PipelineState` flows through the orchestrator: Agent 1 fills `qc_result`;
Agent 2 fills `few_shot_examples`; Agent 3 fills `final_plan`. The
`final_plan` and `few_shot_examples` types are forward-declared as `Any`
until Steps 26 and 39 land their schemas.
"""

from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field

from app.schemas.literature_qc import LiteratureQCResult


class PipelineState(BaseModel):
    """State container passed between runtime agents.

    `few_shot_examples` and `final_plan` are typed loosely here as
    placeholders until the §4 schemas land in Steps 26 (ExperimentPlan)
    and 39 (FewShotExample). They are not permanent widenings: those
    later steps replace `Any` with the concrete types.
    """

    request_id: str = Field(min_length=1)
    hypothesis: str = Field(min_length=1)
    qc_result: LiteratureQCResult | None = None
    few_shot_examples: list[Any] = Field(default_factory=list)
    final_plan: Any | None = None
