import '../../../models/experiment_plan.dart';
import '../../plan/review/models/change_target.dart';
import '../../plan/review/models/feedback_polarity.dart';
import '../../plan/review/models/review_section.dart';
import 'review_kind.dart';

/// One piece of feedback the user gave Marie on a generated experiment
/// plan. Persisted globally (across conversations) and rendered in the
/// Reviewer screen.
sealed class Review {
  const Review({
    required this.id,
    required this.conversationId,
    required this.query,
    required this.originalPlan,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final String query;
  final ExperimentPlan originalPlan;
  final DateTime createdAt;

  ReviewKind get kind;
}

/// A direct edit to a single field in the plan (e.g. step name change,
/// budget total change, etc.).
class CorrectionReview extends Review {
  const CorrectionReview({
    required super.id,
    required super.conversationId,
    required super.query,
    required super.originalPlan,
    required super.createdAt,
    required this.target,
    required this.before,
    required this.after,
  });

  final ChangeTarget target;
  final Object? before;
  final Object? after;

  @override
  ReviewKind get kind => ReviewKind.correction;
}

/// A free-text annotation anchored to a substring of a target field.
class CommentReview extends Review {
  const CommentReview({
    required super.id,
    required super.conversationId,
    required super.query,
    required super.originalPlan,
    required super.createdAt,
    required this.target,
    required this.quote,
    required this.start,
    required this.end,
    required this.body,
  });

  final ChangeTarget target;
  final String quote;
  final int start;
  final int end;
  final String body;

  @override
  ReviewKind get kind => ReviewKind.comment;
}

/// A like/dislike applied to one of the major plan sections.
class FeedbackReview extends Review {
  const FeedbackReview({
    required super.id,
    required super.conversationId,
    required super.query,
    required super.originalPlan,
    required super.createdAt,
    required this.section,
    required this.polarity,
  });

  final ReviewSection section;
  final FeedbackPolarity polarity;

  @override
  ReviewKind get kind => ReviewKind.feedback;
}
