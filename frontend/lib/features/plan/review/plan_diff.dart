import '../../../models/experiment_plan.dart';
import 'models/change_target.dart';
import 'models/material_field.dart';
import 'models/plan_change.dart';
import 'models/step_field.dart';

/// Computes the ordered list of [PlanChange]s required to turn [before]
/// into [after]. Steps and materials are matched by stable id, so insert
/// / remove / reorder all show up cleanly without index drift.
List<PlanChange> diffPlans({
  required ExperimentPlan before,
  required ExperimentPlan after,
}) {
  final List<PlanChange> changes = <PlanChange>[];
  if (before.description != after.description) {
    changes.add(FieldChange(
      target: const PlanDescriptionTarget(),
      before: before.description,
      after: after.description,
    ));
  }
  if (before.budget.total != after.budget.total) {
    changes.add(FieldChange(
      target: const BudgetTotalTarget(),
      before: before.budget.total,
      after: after.budget.total,
    ));
  }
  if (before.timePlan.totalDuration != after.timePlan.totalDuration) {
    changes.add(FieldChange(
      target: const TotalDurationTarget(),
      before: before.timePlan.totalDuration,
      after: after.timePlan.totalDuration,
    ));
  }
  changes.addAll(_diffSteps(before.timePlan.steps, after.timePlan.steps));
  changes.addAll(
    _diffMaterials(before.budget.materials, after.budget.materials),
  );
  return changes;
}

List<PlanChange> _diffSteps(List<Step> before, List<Step> after) {
  final List<PlanChange> changes = <PlanChange>[];
  final Map<String, Step> beforeById = <String, Step>{
    for (final Step step in before) step.id: step,
  };
  final Set<String> afterIds = <String>{
    for (final Step step in after) step.id,
  };
  for (int i = 0; i < before.length; i++) {
    final Step removed = before[i];
    if (!afterIds.contains(removed.id)) {
      changes.add(StepRemoved(index: i, step: removed));
    }
  }
  for (int i = 0; i < after.length; i++) {
    final Step current = after[i];
    final Step? previous = beforeById[current.id];
    if (previous == null) {
      changes.add(StepInserted(index: i, step: current));
      continue;
    }
    changes.addAll(_diffStepFields(previous, current));
  }
  return changes;
}

List<PlanChange> _diffStepFields(Step before, Step after) {
  final List<PlanChange> changes = <PlanChange>[];
  if (before.name != after.name) {
    changes.add(FieldChange(
      target: StepFieldTarget(stepId: after.id, field: StepField.name),
      before: before.name,
      after: after.name,
    ));
  }
  if (before.description != after.description) {
    changes.add(FieldChange(
      target: StepFieldTarget(stepId: after.id, field: StepField.description),
      before: before.description,
      after: after.description,
    ));
  }
  if (before.duration != after.duration) {
    changes.add(FieldChange(
      target: StepFieldTarget(stepId: after.id, field: StepField.duration),
      before: before.duration,
      after: after.duration,
    ));
  }
  if (before.milestone != after.milestone) {
    changes.add(FieldChange(
      target: StepFieldTarget(stepId: after.id, field: StepField.milestone),
      before: before.milestone,
      after: after.milestone,
    ));
  }
  return changes;
}

List<PlanChange> _diffMaterials(List<Material> before, List<Material> after) {
  final List<PlanChange> changes = <PlanChange>[];
  final Map<String, Material> beforeById = <String, Material>{
    for (final Material m in before) m.id: m,
  };
  final Set<String> afterIds = <String>{
    for (final Material m in after) m.id,
  };
  for (int i = 0; i < before.length; i++) {
    final Material removed = before[i];
    if (!afterIds.contains(removed.id)) {
      changes.add(MaterialRemoved(index: i, material: removed));
    }
  }
  for (int i = 0; i < after.length; i++) {
    final Material current = after[i];
    final Material? previous = beforeById[current.id];
    if (previous == null) {
      changes.add(MaterialInserted(index: i, material: current));
      continue;
    }
    changes.addAll(_diffMaterialFields(previous, current));
  }
  return changes;
}

List<PlanChange> _diffMaterialFields(Material before, Material after) {
  final List<PlanChange> changes = <PlanChange>[];
  if (before.title != after.title) {
    changes.add(FieldChange(
      target:
          MaterialFieldTarget(materialId: after.id, field: MaterialField.title),
      before: before.title,
      after: after.title,
    ));
  }
  if (before.catalogNumber != after.catalogNumber) {
    changes.add(FieldChange(
      target: MaterialFieldTarget(
        materialId: after.id,
        field: MaterialField.catalogNumber,
      ),
      before: before.catalogNumber,
      after: after.catalogNumber,
    ));
  }
  if (before.description != after.description) {
    changes.add(FieldChange(
      target: MaterialFieldTarget(
        materialId: after.id,
        field: MaterialField.description,
      ),
      before: before.description,
      after: after.description,
    ));
  }
  if (before.amount != after.amount) {
    changes.add(FieldChange(
      target: MaterialFieldTarget(
        materialId: after.id,
        field: MaterialField.amount,
      ),
      before: before.amount,
      after: after.amount,
    ));
  }
  if (before.price != after.price) {
    changes.add(FieldChange(
      target: MaterialFieldTarget(
        materialId: after.id,
        field: MaterialField.price,
      ),
      before: before.price,
      after: after.price,
    ));
  }
  return changes;
}
