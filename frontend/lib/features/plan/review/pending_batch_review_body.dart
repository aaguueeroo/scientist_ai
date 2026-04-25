import 'package:flutter/material.dart' hide Material, Step;
import 'package:provider/provider.dart';

import '../../../models/experiment_plan.dart';
import 'models/plan_change.dart';
import 'plan_review_controller.dart';
import 'read_only_review_body.dart';

/// Pending-review body. The [PlanReviewController] keeps the "live plan"
/// untouched while a batch is pending; SuggestionAwareText reads the
/// pending change and renders strikethrough+colored automatically. So we
/// reuse [ReadOnlyReviewBody] but feed it a synthetic plan that contains
/// the pending step / material insertions so the user can see them.
class PendingBatchReviewBody extends StatelessWidget {
  const PendingBatchReviewBody({super.key, this.query});

  final String? query;

  @override
  Widget build(BuildContext context) {
    final PlanReviewController controller =
        context.watch<PlanReviewController>();
    final ExperimentPlan livePlan = controller.livePlan;
    final ExperimentPlan composed = _composeWithPendingInsertions(
      livePlan,
      controller,
    );
    return ReadOnlyReviewBody(plan: composed, query: query);
  }

  ExperimentPlan _composeWithPendingInsertions(
    ExperimentPlan plan,
    PlanReviewController controller,
  ) {
    final pendingBatch = controller.pendingBatch;
    if (pendingBatch == null) return plan;
    List<Step> steps = List<Step>.from(plan.timePlan.steps);
    List<Material> materials = List<Material>.from(plan.budget.materials);
    for (final PlanChange change in pendingBatch.changes) {
      if (change is StepInserted) {
        final int idx = change.index.clamp(0, steps.length);
        if (!steps.any((Step s) => s.id == change.step.id)) {
          steps.insert(idx, change.step);
        }
      }
      if (change is MaterialInserted) {
        final int idx = change.index.clamp(0, materials.length);
        if (!materials.any((Material m) => m.id == change.material.id)) {
          materials.insert(idx, change.material);
        }
      }
    }
    final List<Step> renumbered = <Step>[];
    for (int i = 0; i < steps.length; i++) {
      renumbered.add(steps[i].copyWith(number: i + 1));
    }
    return plan.copyWith(
      timePlan: plan.timePlan.copyWith(steps: renumbered),
      budget: plan.budget.copyWith(materials: materials),
    );
  }
}
