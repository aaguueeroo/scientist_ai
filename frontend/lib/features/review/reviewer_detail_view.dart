import 'package:flutter/material.dart' hide Material, Step;
import 'package:provider/provider.dart';

import '../../core/app_constants.dart';
import '../../models/experiment_plan.dart' show ExperimentPlan, Material, Step;
import '../plan/review/models/batch_status.dart';
import '../plan/review/models/change_target.dart';
import '../plan/review/models/comment_anchor.dart';
import '../plan/review/models/feedback_polarity.dart';
import '../plan/review/models/plan_change.dart';
import '../plan/review/models/plan_comment.dart';
import '../plan/review/models/review_section.dart';
import '../plan/review/models/section_feedback.dart';
import '../plan/review/models/suggestion_batch.dart';
import '../plan/review/plan_review_controller.dart';
import '../plan/review/read_only_review_body.dart';
import '../plan/review/review_color_palette.dart';
import 'models/review.dart';
import 'widgets/focus_target_registry.dart';

/// Renders the original plan attached to a single [Review], with the
/// review-specific affordance lit up (highlighted edit, underlined
/// comment, or like/dislike-tinted section border) and auto-scrolled to.
///
/// Reuses the existing [ReadOnlyReviewBody] by spinning up a synthetic,
/// read-only [PlanReviewController] seeded with the review payload.
class ReviewerDetailView extends StatefulWidget {
  const ReviewerDetailView({super.key, required this.review});

  final Review review;

  @override
  State<ReviewerDetailView> createState() => _ReviewerDetailViewState();
}

class _ReviewerDetailViewState extends State<ReviewerDetailView> {
  late PlanReviewController _controller;

  final Map<ChangeTarget, GlobalKey> _targetKeys =
      <ChangeTarget, GlobalKey>{};
  final Map<ReviewSection, GlobalKey> _sectionKeys =
      <ReviewSection, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _controller = _buildController(widget.review);
    _scheduleScrollToFocus();
  }

  @override
  void didUpdateWidget(covariant ReviewerDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.review.id != widget.review.id) {
      _controller.dispose();
      _targetKeys.clear();
      _sectionKeys.clear();
      _controller = _buildController(widget.review);
      _scheduleScrollToFocus();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Returns the [PlanChange] that best represents a structural correction
  /// (step/material insertion or removal). Returns null for regular field
  /// corrections, which are handled as [FieldChange].
  PlanChange? _structuralChangeForReview(CorrectionReview review) {
    final Object? after = review.after;
    final Object? before = review.before;
    if (before == null && after is Step) {
      final int insertIndex = (after.number - 1)
          .clamp(0, review.originalPlan.timePlan.steps.length);
      return StepInserted(index: insertIndex, step: after);
    }
    if (before == null && after is Material) {
      final int insertIndex = review.originalPlan.budget.materials.length;
      return MaterialInserted(index: insertIndex, material: after);
    }
    return null;
  }

  PlanReviewController _buildController(Review review) {
    ChangeTarget? focusedTarget;
    ReviewSection? focusedSection;
    FeedbackPolarity? focusedPolarity;
    List<PlanComment> initialComments = const <PlanComment>[];
    Map<ReviewSection, SectionFeedback> initialSectionFeedback =
        const <ReviewSection, SectionFeedback>{};
    List<SuggestionBatch> initialAcceptedBatches =
        const <SuggestionBatch>[];

    if (review is CorrectionReview) {
      focusedTarget = review.target;
      final PlanChange? structuralChange =
          _structuralChangeForReview(review);
      if (structuralChange != null) {
        initialAcceptedBatches = <SuggestionBatch>[
          SuggestionBatch(
            id: 'review-${review.id}',
            authorId: PlanReviewController.kLocalAuthorId,
            createdAt: review.createdAt,
            color: BatchColorPalette(sessionSeed: 0).colorAt(0),
            status: BatchStatus.accepted,
            changes: <PlanChange>[structuralChange],
          ),
        ];
      } else if (review.before != null || review.after != null) {
        initialAcceptedBatches = <SuggestionBatch>[
          SuggestionBatch(
            id: 'review-${review.id}',
            authorId: PlanReviewController.kLocalAuthorId,
            createdAt: review.createdAt,
            color: BatchColorPalette(sessionSeed: 0).colorAt(0),
            status: BatchStatus.accepted,
            changes: <PlanChange>[
              FieldChange(
                target: review.target,
                before: review.before,
                after: review.after,
              ),
            ],
          ),
        ];
      }
    } else if (review is CommentReview) {
      focusedTarget = review.target;
      initialComments = <PlanComment>[
        PlanComment(
          id: 'review-${review.id}',
          authorId: PlanReviewController.kLocalAuthorId,
          createdAt: review.createdAt,
          anchor: CommentAnchor(
            target: review.target,
            quote: review.quote,
            start: review.start,
            end: review.end,
          ),
          body: review.body,
        ),
      ];
    } else if (review is FeedbackReview) {
      focusedSection = review.section;
      focusedPolarity = review.polarity;
      initialSectionFeedback = <ReviewSection, SectionFeedback>{
        review.section: SectionFeedback(
          polarity: review.polarity,
          authorId: PlanReviewController.kLocalAuthorId,
          at: review.createdAt,
        ),
      };
    }

    return PlanReviewController(
      source: review.originalPlan,
      onLivePlanChanged: _ignoreLivePlanChange,
      conversationId: review.conversationId,
      query: review.query,
      focusedTarget: focusedTarget,
      focusedSection: focusedSection,
      focusedPolarity: focusedPolarity,
      isReadOnlyFocus: true,
      initialComments: initialComments,
      initialSectionFeedback: initialSectionFeedback,
      initialAcceptedBatches: initialAcceptedBatches,
    );
  }

  void _ignoreLivePlanChange(ExperimentPlan _) {
    // No-op: the detail view is read-only; the controller never emits.
  }

  void _scheduleScrollToFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _executeScrollToFocus();
    });
  }

  void _executeScrollToFocus() {
    final Review review = widget.review;
    GlobalKey? key;
    if (review is CorrectionReview) {
      key = _targetKeys[review.target];
    } else if (review is CommentReview) {
      key = _targetKeys[review.target];
    } else if (review is FeedbackReview) {
      key = _sectionKeys[review.section];
    }
    final BuildContext? targetContext = key?.currentContext;
    if (targetContext == null) return;
    Scrollable.ensureVisible(
      targetContext,
      alignment: 0.3,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PlanReviewController>.value(
      value: _controller,
      child: FocusTargetRegistry(
        targetKeys: _targetKeys,
        sectionKeys: _sectionKeys,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            kSpace40,
            kSpace32,
            kSpace40,
            kSpace40,
          ),
          child: ReadOnlyReviewBody(
            plan: _controller.displayPlan,
            query: widget.review.query,
          ),
        ),
      ),
    );
  }
}
