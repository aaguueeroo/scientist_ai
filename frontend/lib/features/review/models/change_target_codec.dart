import '../../plan/review/models/change_target.dart';
import '../../plan/review/models/material_field.dart';
import '../../plan/review/models/step_field.dart';

/// Encodes/decodes [ChangeTarget] to/from the address strings used on the
/// wire (`plan.description`, `step[<id>].name`, `material[<id>].price`, ...).
///
/// The encoding is the same as [ChangeTarget.toString], so a round-trip via
/// `decode(target.toString())` returns an equal target.
class ChangeTargetCodec {
  const ChangeTargetCodec._();

  static const String _kPlanDescription = 'plan.description';
  static const String _kBudgetTotal = 'plan.budget.total';
  static const String _kTotalDuration = 'plan.timePlan.totalDuration';

  static final RegExp _stepPattern =
      RegExp(r'^step\[([^\]]+)\]\.([a-zA-Z]+)$');
  static final RegExp _materialPattern =
      RegExp(r'^material\[([^\]]+)\]\.([a-zA-Z]+)$');

  static String encode(ChangeTarget target) => target.toString();

  /// Returns null if [address] does not match any known target shape.
  static ChangeTarget? decode(String address) {
    if (address == _kPlanDescription) {
      return const PlanDescriptionTarget();
    }
    if (address == _kBudgetTotal) {
      return const BudgetTotalTarget();
    }
    if (address == _kTotalDuration) {
      return const TotalDurationTarget();
    }
    final RegExpMatch? stepMatch = _stepPattern.firstMatch(address);
    if (stepMatch != null) {
      final String stepId = stepMatch.group(1)!;
      final StepField? field = _stepFieldFromName(stepMatch.group(2)!);
      if (field == null) return null;
      return StepFieldTarget(stepId: stepId, field: field);
    }
    final RegExpMatch? materialMatch = _materialPattern.firstMatch(address);
    if (materialMatch != null) {
      final String materialId = materialMatch.group(1)!;
      final MaterialField? field =
          _materialFieldFromName(materialMatch.group(2)!);
      if (field == null) return null;
      return MaterialFieldTarget(materialId: materialId, field: field);
    }
    return null;
  }

  static StepField? _stepFieldFromName(String name) {
    for (final StepField f in StepField.values) {
      if (f.name == name) return f;
    }
    return null;
  }

  static MaterialField? _materialFieldFromName(String name) {
    for (final MaterialField f in MaterialField.values) {
      if (f.name == name) return f;
    }
    return null;
  }
}
