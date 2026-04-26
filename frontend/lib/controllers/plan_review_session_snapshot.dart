import '../features/plan/review/models/plan_comment.dart';
import '../features/plan/review/models/plan_version.dart';
import '../features/plan/review/models/review_section.dart';
import '../features/plan/review/models/section_feedback.dart';
import '../features/plan/review/models/suggestion_batch.dart';
import '../features/plan/review/plan_review_controller.dart';
import '../models/experiment_plan.dart';

/// In-memory plan-review state for one conversation (version history,
/// comments, section feedback). Survives navigation while the app runs.
class PlanReviewSessionSnapshot {
  PlanReviewSessionSnapshot({
    required this.originalPlan,
    required List<PlanVersion> versions,
    required List<SuggestionBatch> acceptedBatches,
    required List<PlanComment> comments,
    required Map<ReviewSection, SectionFeedback> sectionFeedback,
    this.viewingVersionId,
  })  : versions = List<PlanVersion>.generate(
          versions.length,
          (int i) {
            final PlanVersion v = versions[i];
            return PlanVersion(
              id: v.id,
              snapshot: deepCopyExperimentPlan(v.snapshot),
              batchId: v.batchId,
              authorId: v.authorId,
              at: v.at,
              changeCount: v.changeCount,
            );
          },
          growable: false,
        ),
        acceptedBatches = List<SuggestionBatch>.from(acceptedBatches),
        comments = List<PlanComment>.from(comments),
        sectionFeedback =
            Map<ReviewSection, SectionFeedback>.from(sectionFeedback);

  final ExperimentPlan originalPlan;
  final List<PlanVersion> versions;
  final List<SuggestionBatch> acceptedBatches;
  final List<PlanComment> comments;
  final Map<ReviewSection, SectionFeedback> sectionFeedback;
  final String? viewingVersionId;

  factory PlanReviewSessionSnapshot.fromController(
    PlanReviewController controller,
  ) {
    final bool dropHistoricalFocus =
        controller.mode == ReviewMode.editing;
    return PlanReviewSessionSnapshot(
      originalPlan: deepCopyExperimentPlan(controller.original),
      versions: controller.versions,
      acceptedBatches: controller.acceptedBatches,
      comments: controller.comments,
      sectionFeedback: controller.sectionFeedback,
      viewingVersionId:
          dropHistoricalFocus ? null : controller.viewingVersionId,
    );
  }
}
