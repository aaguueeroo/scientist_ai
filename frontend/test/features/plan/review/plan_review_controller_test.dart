import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scientist_ai/features/plan/review/models/batch_status.dart';
import 'package:scientist_ai/features/plan/review/models/change_target.dart';
import 'package:scientist_ai/features/plan/review/models/plan_change.dart';
import 'package:scientist_ai/features/plan/review/models/plan_comment.dart';
import 'package:scientist_ai/features/plan/review/models/step_field.dart';
import 'package:scientist_ai/features/plan/review/models/suggestion_batch.dart';
import 'package:scientist_ai/features/plan/review/plan_review_controller.dart';
import 'package:scientist_ai/features/plan/review/review_color_palette.dart';
import 'package:scientist_ai/models/experiment_plan.dart';

const Step _kStepA = Step(
  id: 'step-a',
  number: 1,
  duration: Duration(days: 1),
  name: 'Setup',
  description: 'Calibrate the equipment carefully',
);

const Step _kStepB = Step(
  id: 'step-b',
  number: 2,
  duration: Duration(days: 2),
  name: 'Execute',
  description: 'Run the experiment',
);

ExperimentPlan _buildPlan() {
  return const ExperimentPlan(
    description: 'Original description',
    budget: Budget(total: 1000, materials: <Material>[]),
    timePlan: TimePlan(
      totalDuration: Duration(days: 30),
      steps: <Step>[_kStepA, _kStepB],
    ),
  );
}

PlanReviewController _buildController({
  ValueChanged<ExperimentPlan>? onLivePlanChanged,
}) {
  return PlanReviewController(
    source: _buildPlan(),
    onLivePlanChanged: onLivePlanChanged ?? (ExperimentPlan _) {},
    palette: BatchColorPalette(sessionSeed: 0),
  );
}

void main() {
  group('PlanReviewController editing flow', () {
    test('applySuggestions creates a pending batch with the diff', () {
      final PlanReviewController controller = _buildController();

      controller.enterEditing();
      controller.updateStep(
        0,
        _kStepA.copyWith(name: 'Setup (revised)'),
      );
      controller.applySuggestions();

      expect(controller.mode, ReviewMode.reviewingPending);
      final SuggestionBatch? actualPending = controller.pendingBatch;
      expect(actualPending, isNotNull);
      expect(actualPending!.status, BatchStatus.pending);
      expect(actualPending.changes.length, 1);
      final FieldChange actualChange =
          actualPending.changes.single as FieldChange;
      expect((actualChange.target as StepFieldTarget).stepId, 'step-a');
      expect(actualChange.after, 'Setup (revised)');
    });

    test('applySuggestions with no diff returns to viewing mode', () {
      final PlanReviewController controller = _buildController();

      controller.enterEditing();
      controller.applySuggestions();

      expect(controller.mode, ReviewMode.viewing);
      expect(controller.pendingBatch, isNull);
    });

    test('discardPendingBatch clears pending state without mutating live plan',
        () {
      final PlanReviewController controller = _buildController();
      final ExperimentPlan expectedLive = controller.livePlan;

      controller.enterEditing();
      controller.updateStep(
        0,
        _kStepA.copyWith(name: 'Setup (revised)'),
      );
      controller.applySuggestions();
      controller.discardPendingBatch();

      expect(controller.mode, ReviewMode.viewing);
      expect(controller.pendingBatch, isNull);
      expect(controller.livePlan.timePlan.steps.first.name, expectedLive.timePlan.steps.first.name);
    });
  });

  group('PlanReviewController batch acceptance', () {
    test('acceptPendingBatch promotes batch, updates live plan and history',
        () {
      ExperimentPlan? actualEmittedPlan;
      final PlanReviewController controller = _buildController(
        onLivePlanChanged: (ExperimentPlan p) => actualEmittedPlan = p,
      );

      controller.enterEditing();
      controller.updateStep(0, _kStepA.copyWith(name: 'Setup (revised)'));
      controller.applySuggestions();
      controller.acceptPendingBatch();

      expect(controller.mode, ReviewMode.viewing);
      expect(controller.pendingBatch, isNull);
      expect(controller.acceptedBatches.length, 1);
      expect(
        controller.acceptedBatches.single.status,
        BatchStatus.accepted,
      );
      expect(controller.livePlan.timePlan.steps.first.name, 'Setup (revised)');
      expect(controller.versions.length, 2);
      expect(actualEmittedPlan, isNotNull);
      expect(actualEmittedPlan!.timePlan.steps.first.name, 'Setup (revised)');
    });

    test('colorForTarget returns the color of the latest accepted batch', () {
      final PlanReviewController controller = _buildController();
      const StepFieldTarget inputTarget =
          StepFieldTarget(stepId: 'step-a', field: StepField.name);

      expect(controller.colorForTarget(inputTarget), isNull);

      controller.enterEditing();
      controller.updateStep(0, _kStepA.copyWith(name: 'Renamed'));
      controller.applySuggestions();
      controller.acceptPendingBatch();

      final SuggestionBatch acceptedBatch =
          controller.acceptedBatches.single;
      expect(controller.colorForTarget(inputTarget), acceptedBatch.color);
    });
  });

  group('PlanReviewController comment re-anchoring', () {
    test('keeps anchor offsets when text is unchanged', () {
      final PlanReviewController controller = _buildController();
      const StepFieldTarget inputTarget =
          StepFieldTarget(stepId: 'step-a', field: StepField.description);
      final String inputText = _kStepA.description;
      const String inputQuote = 'equipment';
      final int inputStart = inputText.indexOf(inputQuote);

      controller.addComment(
        target: inputTarget,
        quote: inputQuote,
        start: inputStart,
        end: inputStart + inputQuote.length,
        body: 'Which equipment exactly?',
      );

      final List<PlanComment> actualMatched =
          controller.commentsForTarget(inputTarget, inputText);
      expect(actualMatched.length, 1);
      expect(actualMatched.single.anchor.start, inputStart);
    });

    test('shifts anchor when surrounding text changes but quote remains', () {
      final PlanReviewController controller = _buildController();
      const StepFieldTarget inputTarget =
          StepFieldTarget(stepId: 'step-a', field: StepField.description);
      const String inputQuote = 'equipment';
      final int inputStart = _kStepA.description.indexOf(inputQuote);

      controller.addComment(
        target: inputTarget,
        quote: inputQuote,
        start: inputStart,
        end: inputStart + inputQuote.length,
        body: 'Which one?',
      );

      controller.enterEditing();
      controller.updateStep(
        0,
        _kStepA.copyWith(
          description: 'Prepare and calibrate the equipment carefully',
        ),
      );
      controller.applySuggestions();
      controller.acceptPendingBatch();

      final List<PlanComment> actualMatched =
          controller.commentsForTarget(inputTarget, controller.livePlan.timePlan.steps[0].description);
      expect(actualMatched.length, 1);
      expect(
        actualMatched.single.anchor.start,
        controller.livePlan.timePlan.steps[0].description.indexOf(inputQuote),
      );
    });

    test('marks comment stale when quote disappears from live plan', () {
      final PlanReviewController controller = _buildController();
      const StepFieldTarget inputTarget =
          StepFieldTarget(stepId: 'step-a', field: StepField.description);
      const String inputQuote = 'equipment';
      final int inputStart = _kStepA.description.indexOf(inputQuote);

      controller.addComment(
        target: inputTarget,
        quote: inputQuote,
        start: inputStart,
        end: inputStart + inputQuote.length,
        body: 'Which one?',
      );

      controller.enterEditing();
      controller.updateStep(
        0,
        _kStepA.copyWith(description: 'Prepare the laboratory carefully'),
      );
      controller.applySuggestions();
      controller.acceptPendingBatch();

      expect(controller.staleComments.length, 1);
      expect(controller.staleComments.single.body, 'Which one?');
    });
  });
}
