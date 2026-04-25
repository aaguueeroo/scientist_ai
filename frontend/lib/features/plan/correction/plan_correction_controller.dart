import 'package:flutter/foundation.dart';

import '../../../models/experiment_plan.dart';

class PlanCorrectionController extends ChangeNotifier {
  PlanCorrectionController({
    required ExperimentPlan source,
    required ValueChanged<ExperimentPlan> onSave,
  })  : _draft = source,
        _onSave = onSave;

  final ValueChanged<ExperimentPlan> _onSave;
  ExperimentPlan _draft;

  ExperimentPlan get draft => _draft;

  void updateTotalDuration(Duration value) {
    if (value.isNegative || value == _draft.timePlan.totalDuration) {
      return;
    }
    _draft = _draft.copyWith(
      timePlan: _draft.timePlan.copyWith(totalDuration: value),
    );
    notifyListeners();
  }

  void updateBudgetTotal(double value) {
    if (value < 0 || value == _draft.budget.total) {
      return;
    }
    _draft = _draft.copyWith(
      budget: _draft.budget.copyWith(total: value),
    );
    notifyListeners();
  }

  void updateStep(int index, Step step) {
    if (index < 0 || index >= _draft.timePlan.steps.length) {
      return;
    }
    final List<Step> next = List<Step>.from(_draft.timePlan.steps);
    next[index] = step.copyWith(number: index + 1);
    _draft = _draft.copyWith(
      timePlan: _draft.timePlan.copyWith(steps: next),
    );
    notifyListeners();
  }

  void insertStepAt(int afterIndex) {
    final List<Step> current = _draft.timePlan.steps;
    final int insertIndex = (afterIndex + 1).clamp(0, current.length);
    final Step blank = Step.blank(number: insertIndex + 1);
    final List<Step> next = List<Step>.from(current)..insert(insertIndex, blank);
    _draft = _draft.copyWith(
      timePlan: _draft.timePlan.copyWith(steps: _renumber(next)),
    );
    notifyListeners();
  }

  void appendStep() {
    final List<Step> current = _draft.timePlan.steps;
    final List<Step> next = List<Step>.from(current)
      ..add(Step.blank(number: current.length + 1));
    _draft = _draft.copyWith(
      timePlan: _draft.timePlan.copyWith(steps: next),
    );
    notifyListeners();
  }

  void removeStep(int index) {
    final List<Step> current = _draft.timePlan.steps;
    if (index < 0 || index >= current.length) {
      return;
    }
    final List<Step> next = List<Step>.from(current)..removeAt(index);
    _draft = _draft.copyWith(
      timePlan: _draft.timePlan.copyWith(steps: _renumber(next)),
    );
    notifyListeners();
  }

  void updateMaterial(int index, Material material) {
    if (index < 0 || index >= _draft.budget.materials.length) {
      return;
    }
    final List<Material> next = List<Material>.from(_draft.budget.materials);
    next[index] = material;
    _draft = _draft.copyWith(
      budget: _draft.budget.copyWith(materials: next),
    );
    notifyListeners();
  }

  void appendMaterial() {
    final List<Material> next = List<Material>.from(_draft.budget.materials)
      ..add(Material.blank());
    _draft = _draft.copyWith(
      budget: _draft.budget.copyWith(materials: next),
    );
    notifyListeners();
  }

  void removeMaterial(int index) {
    final List<Material> current = _draft.budget.materials;
    if (index < 0 || index >= current.length) {
      return;
    }
    final List<Material> next = List<Material>.from(current)..removeAt(index);
    _draft = _draft.copyWith(
      budget: _draft.budget.copyWith(materials: next),
    );
    notifyListeners();
  }

  void save() {
    _onSave(_draft);
  }

  List<Step> _renumber(List<Step> steps) {
    final List<Step> next = <Step>[];
    for (int i = 0; i < steps.length; i++) {
      next.add(steps[i].copyWith(number: i + 1));
    }
    return next;
  }
}
