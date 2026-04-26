import '../../../../models/experiment_plan.dart';
import 'change_target.dart';

/// A single atomic change captured in a [SuggestionBatch]. Each subclass
/// represents one of the diff operations the controller can produce.
sealed class PlanChange {
  const PlanChange();
}

/// A scalar change to a single field (text, number, duration, etc).
class FieldChange extends PlanChange {
  const FieldChange({
    required this.target,
    required this.before,
    required this.after,
  });

  final ChangeTarget target;
  final Object? before;
  final Object? after;
}

/// A new step inserted at [index] in the steps list.
class StepInserted extends PlanChange {
  const StepInserted({required this.index, required this.step});

  final int index;
  final Step step;
}

/// An existing step removed from the steps list.
class StepRemoved extends PlanChange {
  const StepRemoved({required this.index, required this.step});

  final int index;
  final Step step;
}

/// A new material inserted at [index] in the materials list.
class MaterialInserted extends PlanChange {
  const MaterialInserted({required this.index, required this.material});

  final int index;
  final Material material;
}

/// An existing material removed from the materials list.
class MaterialRemoved extends PlanChange {
  const MaterialRemoved({required this.index, required this.material});

  final int index;
  final Material material;
}
