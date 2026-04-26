import 'material_field.dart';
import 'step_field.dart';

/// Stable address for a piece of plan content that may carry suggestions
/// or comments. Subclasses override [==] / [hashCode] so targets behave
/// well as map keys and set members.
sealed class ChangeTarget {
  const ChangeTarget();
}

class PlanDescriptionTarget extends ChangeTarget {
  const PlanDescriptionTarget();

  @override
  bool operator ==(Object other) => other is PlanDescriptionTarget;

  @override
  int get hashCode => 0x100001;

  @override
  String toString() => 'plan.description';
}

class BudgetTotalTarget extends ChangeTarget {
  const BudgetTotalTarget();

  @override
  bool operator ==(Object other) => other is BudgetTotalTarget;

  @override
  int get hashCode => 0x100002;

  @override
  String toString() => 'plan.budget.total';
}

class TotalDurationTarget extends ChangeTarget {
  const TotalDurationTarget();

  @override
  bool operator ==(Object other) => other is TotalDurationTarget;

  @override
  int get hashCode => 0x100003;

  @override
  String toString() => 'plan.timePlan.totalDuration';
}

class StepFieldTarget extends ChangeTarget {
  const StepFieldTarget({required this.stepId, required this.field});

  final String stepId;
  final StepField field;

  @override
  bool operator ==(Object other) {
    return other is StepFieldTarget &&
        other.stepId == stepId &&
        other.field == field;
  }

  @override
  int get hashCode => Object.hash('step', stepId, field);

  @override
  String toString() => 'step[$stepId].${field.name}';
}

class MaterialFieldTarget extends ChangeTarget {
  const MaterialFieldTarget({required this.materialId, required this.field});

  final String materialId;
  final MaterialField field;

  @override
  bool operator ==(Object other) {
    return other is MaterialFieldTarget &&
        other.materialId == materialId &&
        other.field == field;
  }

  @override
  int get hashCode => Object.hash('material', materialId, field);

  @override
  String toString() => 'material[$materialId].${field.name}';
}
