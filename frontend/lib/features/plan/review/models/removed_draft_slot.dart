import '../../../../models/experiment_plan.dart';

/// A pending tombstone for a step removed from the current edit draft.
///
/// [afterDraftStepId] points at the step still present in the draft after
/// which the tombstone should be rendered. When `null`, the tombstone
/// should appear before the first remaining step (or in the only slot if
/// the draft has no steps left).
class RemovedStepSlot {
  const RemovedStepSlot({
    required this.step,
    required this.baselineIndex,
    required this.afterDraftStepId,
  });

  final Step step;
  final int baselineIndex;
  final String? afterDraftStepId;
}

/// Same as [RemovedStepSlot] for materials.
class RemovedMaterialSlot {
  const RemovedMaterialSlot({
    required this.material,
    required this.baselineIndex,
    required this.afterDraftMaterialId,
  });

  final Material material;
  final int baselineIndex;
  final String? afterDraftMaterialId;
}
