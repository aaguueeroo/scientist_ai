import '../../models/experiment_plan.dart' show Material, Step;
import '../plan/review/models/feedback_polarity.dart';
import 'models/review.dart';

/// Helper used by both the list tile and the detail header.
String describeReview(Review review) {
  if (review is CorrectionReview) {
    final Object? after = review.after;
    final Object? before = review.before;
    if (before == null && after is Step) {
      return 'Added step "${after.name}"';
    }
    if (before is Step && after == null) {
      return 'Removed step "${before.name}"';
    }
    if (before == null && after is Material) {
      return 'Added material "${after.title}"';
    }
    if (before is Material && after == null) {
      return 'Removed material "${before.title}"';
    }
    return 'Edited ${_describeTarget(review.target.toString())}';
  }
  if (review is CommentReview) {
    return 'Comment on ${_describeTarget(review.target.toString())}';
  }
  if (review is FeedbackReview) {
    final String verb =
        review.polarity == FeedbackPolarity.like ? 'Liked' : 'Disliked';
    return '$verb ${_describeSection(review)}';
  }
  return 'Review';
}

String _describeSection(FeedbackReview review) {
  switch (review.section.name) {
    case 'totalTime':
      return 'total time';
    case 'budget':
      return 'budget';
    case 'timeline':
      return 'timeline';
    case 'steps':
      return 'steps';
    case 'materials':
      return 'materials';
    case 'validation':
      return 'validation';
    case 'risks':
      return 'risks';
  }
  return review.section.name;
}

String _describeTarget(String target) {
  if (target == 'plan.description') return 'description';
  if (target == 'plan.budget.total') return 'budget total';
  if (target == 'plan.timePlan.totalDuration') return 'total duration';
  if (target.startsWith('step[')) {
    final RegExpMatch? match = RegExp(r'step\[[^\]]+\]\.(\w+)').firstMatch(
      target,
    );
    if (match != null) return 'step ${match.group(1)}';
  }
  if (target.startsWith('material[')) {
    final RegExpMatch? match = RegExp(r'material\[[^\]]+\]\.(\w+)').firstMatch(
      target,
    );
    if (match != null) return 'material ${match.group(1)}';
  }
  return target;
}
