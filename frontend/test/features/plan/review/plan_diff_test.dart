import 'package:flutter_test/flutter_test.dart';
import 'package:scientist_ai/features/plan/review/models/change_target.dart';
import 'package:scientist_ai/features/plan/review/models/material_field.dart';
import 'package:scientist_ai/features/plan/review/models/plan_change.dart';
import 'package:scientist_ai/features/plan/review/models/step_field.dart';
import 'package:scientist_ai/features/plan/review/plan_diff.dart';
import 'package:scientist_ai/models/experiment_plan.dart';

ExperimentPlan _buildPlan({
  String description = 'Original description',
  double total = 1000,
  Duration totalDuration = const Duration(days: 30),
  List<Step>? steps,
  List<Material>? materials,
}) {
  return ExperimentPlan(
    description: description,
    budget: Budget(total: total, materials: materials ?? <Material>[]),
    timePlan: TimePlan(
      totalDuration: totalDuration,
      steps: steps ?? <Step>[],
    ),
  );
}

void main() {
  group('diffPlans', () {
    test('returns empty list when plans are identical', () {
      final ExperimentPlan inputPlan = _buildPlan();
      final List<PlanChange> actualChanges =
          diffPlans(before: inputPlan, after: inputPlan);
      expect(actualChanges, isEmpty);
    });

    test('detects description, budget total and total duration changes', () {
      final ExperimentPlan inputBefore = _buildPlan();
      final ExperimentPlan inputAfter = _buildPlan(
        description: 'Updated description',
        total: 1500,
        totalDuration: const Duration(days: 45),
      );

      final List<PlanChange> actualChanges =
          diffPlans(before: inputBefore, after: inputAfter);

      final Iterable<FieldChange> fieldChanges =
          actualChanges.whereType<FieldChange>();
      expect(fieldChanges.length, 3);
      expect(
        fieldChanges.any(
          (FieldChange c) =>
              c.target is PlanDescriptionTarget &&
              c.before == 'Original description' &&
              c.after == 'Updated description',
        ),
        isTrue,
      );
      expect(
        fieldChanges.any(
          (FieldChange c) =>
              c.target is BudgetTotalTarget &&
              c.before == 1000.0 &&
              c.after == 1500.0,
        ),
        isTrue,
      );
      expect(
        fieldChanges.any(
          (FieldChange c) =>
              c.target is TotalDurationTarget &&
              c.before == const Duration(days: 30) &&
              c.after == const Duration(days: 45),
        ),
        isTrue,
      );
    });

    test('detects step insertion, removal and field change by stable id', () {
      const Step inputKept = Step(
        id: 'step-keep',
        number: 1,
        duration: Duration(days: 1),
        name: 'Keep me',
        description: 'desc',
      );
      const Step inputRemoved = Step(
        id: 'step-remove',
        number: 2,
        duration: Duration(days: 1),
        name: 'Remove me',
        description: 'desc',
      );
      final Step inputRenamed = inputKept.copyWith(name: 'Renamed step');
      const Step inputInserted = Step(
        id: 'step-new',
        number: 2,
        duration: Duration(days: 2),
        name: 'New step',
        description: 'fresh',
      );

      final ExperimentPlan inputBefore =
          _buildPlan(steps: <Step>[inputKept, inputRemoved]);
      final ExperimentPlan inputAfter =
          _buildPlan(steps: <Step>[inputRenamed, inputInserted]);

      final List<PlanChange> actualChanges =
          diffPlans(before: inputBefore, after: inputAfter);

      expect(
        actualChanges.whereType<StepRemoved>().single.step.id,
        'step-remove',
      );
      expect(
        actualChanges.whereType<StepInserted>().single.step.id,
        'step-new',
      );
      final FieldChange actualNameChange = actualChanges
          .whereType<FieldChange>()
          .firstWhere(
            (FieldChange c) =>
                c.target is StepFieldTarget &&
                (c.target as StepFieldTarget).field == StepField.name,
          );
      expect(
        (actualNameChange.target as StepFieldTarget).stepId,
        'step-keep',
      );
      expect(actualNameChange.before, 'Keep me');
      expect(actualNameChange.after, 'Renamed step');
    });

    test('detects material price change without insertions', () {
      const Material inputMaterial = Material(
        id: 'mat-1',
        title: 'Reagent A',
        catalogNumber: 'A-001',
        description: 'High purity',
        amount: 1,
        price: 50,
      );
      final Material inputUpdated = inputMaterial.copyWith(price: 75);

      final ExperimentPlan inputBefore =
          _buildPlan(materials: <Material>[inputMaterial]);
      final ExperimentPlan inputAfter =
          _buildPlan(materials: <Material>[inputUpdated]);

      final List<PlanChange> actualChanges =
          diffPlans(before: inputBefore, after: inputAfter);

      final FieldChange actualPriceChange =
          actualChanges.whereType<FieldChange>().single;
      expect(
        (actualPriceChange.target as MaterialFieldTarget).field,
        MaterialField.price,
      );
      expect(actualPriceChange.before, 50.0);
      expect(actualPriceChange.after, 75.0);
    });
  });
}
