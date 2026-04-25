"""Per-request runtime pipeline state.

`PipelineState` flows through the orchestrator: Agent 1 fills `qc_result`;
Agent 2 fills `few_shot_examples`; Agent 3 fills `final_plan`. The
`few_shot_examples` field is forward-declared as `Any` until Step 39
lands the `FewShotExample` schema.
"""

from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field

from app.schemas.experiment_plan import ExperimentPlan
from app.schemas.literature_qc import LiteratureQCResult


class PipelineState(BaseModel):
    """State container passed between runtime agents.

    `few_shot_examples` is typed loosely here as a placeholder until the
    `FewShotExample` schema lands in Step 39. It is not a permanent
    widening: that step replaces `Any` with the concrete type.
    """

    request_id: str = Field(min_length=1)
    hypothesis: str = Field(min_length=1)
    qc_result: LiteratureQCResult | None = None
    few_shot_examples: list[Any] = Field(default_factory=list)
    final_plan: ExperimentPlan | None = None


PipelineState.model_rebuild()
