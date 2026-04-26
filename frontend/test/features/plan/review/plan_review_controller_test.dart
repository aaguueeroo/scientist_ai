import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scientist_ai/features/plan/review/models/batch_status.dart';
import 'package:scientist_ai/features/plan/review/models/change_target.dart';
import 'package:scientist_ai/features/plan/review/models/material_field.dart';
import 'package:scientist_ai/features/plan/review/models/plan_change.dart';
import 'package:scientist_ai/features/plan/review/models/plan_comment.dart';
import 'package:scientist_ai/features/plan/review/models/removed_draft_slot.dart';
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
    test(
      'applySuggestions commits the draft as a single accepted batch and '
      'updates the live plan',
      () {
        ExperimentPlan? actualEmittedPlan;
        final PlanReviewController controller = _buildController(
          onLivePlanChanged: (ExperimentPlan p) => actualEmittedPlan = p,
        );

        controller.enterEditing();
        controller.updateStep(
          0,
          _kStepA.copyWith(name: 'Setup (revised)'),
        );
        controller.applySuggestions();

        expect(controller.mode, ReviewMode.viewing);
        expect(controller.draft, isNull);
        expect(controller.editBaseline, isNull);
        expect(controller.acceptedBatches.length, 1);
        final SuggestionBatch actualAccepted =
            controller.acceptedBatches.single;
        expect(actualAccepted.status, BatchStatus.accepted);
        expect(actualAccepted.changes.length, 1);
        final FieldChange actualChange =
            actualAccepted.changes.single as FieldChange;
        expect((actualChange.target as StepFieldTarget).stepId, 'step-a');
        expect(actualChange.after, 'Setup (revised)');
        expect(
          controller.livePlan.timePlan.steps.first.name,
          'Setup (revised)',
        );
        expect(controller.versions.length, 2);
        expect(actualEmittedPlan, isNotNull);
        expect(
          actualEmittedPlan!.timePlan.steps.first.name,
          'Setup (revised)',
        );
      },
    );

    test('applySuggestions with no diff returns to viewing mode', () {
      final PlanReviewController controller = _buildController();

      controller.enterEditing();
      controller.applySuggestions();

      expect(controller.mode, ReviewMode.viewing);
      expect(controller.acceptedBatches, isEmpty);
      expect(controller.versions.length, 1);
    });

    test('cancelEditing leaves the live plan untouched', () {
      final PlanReviewController controller = _buildController();
      final ExperimentPlan expectedLive = controller.livePlan;

      controller.enterEditing();
      controller.updateStep(
        0,
        _kStepA.copyWith(name: 'Setup (revised)'),
      );
      controller.cancelEditing();

      expect(controller.mode, ReviewMode.viewing);
      expect(controller.acceptedBatches, isEmpty);
      expect(
        controller.livePlan.timePlan.steps.first.name,
        expectedLive.timePlan.steps.first.name,
      );
    });
  });

  group('PlanReviewController batch acceptance', () {
    test('colorForTarget returns the color of the latest accepted batch', () {
      final PlanReviewController controller = _buildController();
      const StepFieldTarget inputTarget =
          StepFieldTarget(stepId: 'step-a', field: StepField.name);

      expect(controller.colorForTarget(inputTarget), isNull);

      controller.enterEditing();
      controller.updateStep(0, _kStepA.copyWith(name: 'Renamed'));
      controller.applySuggestions();

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

      expect(controller.staleComments.length, 1);
      expect(controller.staleComments.single.body, 'Which one?');
    });
  });

  group('PlanReviewController draft-diff helpers', () {
    test('reports zero changes when nothing has been edited', () {
      final PlanReviewController controller = _buildController();
      controller.enterEditing();

      expect(controller.draftChangedStepFields('step-a'), isEmpty);
      expect(controller.draftChangedMaterialFields('material-x'), isEmpty);
      expect(
        controller.isDraftFieldChanged(const TotalDurationTarget()),
        isFalse,
      );
      expect(
        controller.isDraftFieldChanged(const BudgetTotalTarget()),
        isFalse,
      );
      expect(controller.draftRemovedStepSlots, isEmpty);
      expect(controller.draftRemovedMaterialSlots, isEmpty);
    });

    test('isStepInsertedInDraft is true only for steps not in baseline', () {
      final PlanReviewController controller = _buildController();
      controller.enterEditing();
      final int initialLength =
          controller.draft!.timePlan.steps.length;
      controller.appendStep();

      final String insertedId =
          controller.draft!.timePlan.steps.last.id;
      expect(controller.draft!.timePlan.steps.length, initialLength + 1);
      expect(controller.isStepInsertedInDraft(insertedId), isTrue);
      expect(controller.isStepInsertedInDraft('step-a'), isFalse);
    });

    test('draftChangedStepFields returns the precise changed fields', () {
      final PlanReviewController controller = _buildController();
      controller.enterEditing();
      controller.updateStep(
        0,
        _kStepA.copyWith(
          name: 'Setup (revised)',
          duration: const Duration(days: 3),
        ),
      );

      final Set<StepField> actualChanged =
          controller.draftChangedStepFields('step-a');
      expect(actualChanged, <StepField>{StepField.name, StepField.duration});
      expect(controller.draftChangedStepFields('step-b'), isEmpty);
    });

    test('draftChangedMaterialFields detects scalar field changes', () {
      const Material baseMaterial = Material(
        id: 'material-1',
        title: 'Reagent',
        catalogNumber: 'A-100',
        description: 'Sterile',
        amount: 2,
        price: 12.0,
      );
      final ExperimentPlan inputPlan = ExperimentPlan(
        description: 'Plan',
        budget: const Budget(total: 24, materials: <Material>[baseMaterial]),
        timePlan: const TimePlan(
          totalDuration: Duration(days: 1),
          steps: <Step>[],
        ),
      );
      final PlanReviewController controller = PlanReviewController(
        source: inputPlan,
        onLivePlanChanged: (ExperimentPlan _) {},
        palette: BatchColorPalette(sessionSeed: 0),
      );
      controller.enterEditing();
      controller.updateMaterial(0, baseMaterial.copyWith(amount: 5));

      final Set<MaterialField> actualChanged =
          controller.draftChangedMaterialFields('material-1');
      expect(actualChanged, <MaterialField>{MaterialField.amount});
    });

    test(
      'isDraftFieldChanged tracks plan-level scalars',
      () {
        final PlanReviewController controller = _buildController();
        controller.enterEditing();
        controller.updateBudgetTotal(2500);

        expect(
          controller.isDraftFieldChanged(const BudgetTotalTarget()),
          isTrue,
        );
        expect(
          controller.isDraftFieldChanged(const TotalDurationTarget()),
          isFalse,
        );
      },
    );

    test('draftRemovedStepSlots anchors to the previous surviving step', () {
      final PlanReviewController controller = _buildController();
      controller.enterEditing();
      controller.removeStep(1);

      final List<RemovedStepSlot> actualSlots =
          controller.draftRemovedStepSlots;
      expect(actualSlots.length, 1);
      expect(actualSlots.single.step.id, 'step-b');
      expect(actualSlots.single.afterDraftStepId, 'step-a');
    });

    test(
      'draftRemovedStepSlots anchors first removal to null (top) when '
      'no surviving step precedes it',
      () {
        final PlanReviewController controller = _buildController();
        controller.enterEditing();
        controller.removeStep(0);

        final List<RemovedStepSlot> actualSlots =
            controller.draftRemovedStepSlots;
        expect(actualSlots.length, 1);
        expect(actualSlots.single.step.id, 'step-a');
        expect(actualSlots.single.afterDraftStepId, isNull);
      },
    );

    test('cancelEditing clears the baseline and draft', () {
      final PlanReviewController controller = _buildController();
      controller.enterEditing();
      controller.updateStep(0, _kStepA.copyWith(name: 'Other'));

      expect(
        controller.draftChangedStepFields('step-a'),
        contains(StepField.name),
      );

      controller.cancelEditing();

      expect(controller.editBaseline, isNull);
      expect(controller.draft, isNull);
      expect(controller.draftChangedStepFields('step-a'), isEmpty);
    });
  });
}
