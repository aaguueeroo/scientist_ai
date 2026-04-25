import 'package:flutter/material.dart' hide Material, Step;
import 'package:provider/provider.dart';

import '../../controllers/review_store_controller.dart';
import '../../core/app_constants.dart';
import '../../core/theme/theme_context.dart';
import '../plan/review/models/feedback_polarity.dart';
import 'models/review.dart';
import 'reviewer_detail_view.dart';
import 'widgets/review_list_pane.dart';

const double _kReviewListPaneWidth = 360;

/// Top-level Reviewer surface: list of every persisted review on the left,
/// detail view of the currently-selected review on the right.
class ReviewerScreen extends StatefulWidget {
  const ReviewerScreen({super.key});

  @override
  State<ReviewerScreen> createState() => _ReviewerScreenState();
}

class _ReviewerScreenState extends State<ReviewerScreen> {
  String? _selectedReviewId;

  void _selectReview(String id) {
    setState(() => _selectedReviewId = id);
  }

  Review? _findSelected(List<Review> reviews) {
    final String? id = _selectedReviewId;
    if (id == null) return null;
    for (final Review r in reviews) {
      if (r.id == id) return r;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ReviewStoreController store =
        context.watch<ReviewStoreController>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        kSpace32,
        kSpace32,
        kSpace32,
        kSpace32,
      ),
      child: _buildBody(context, store),
    );
  }

  Widget _buildBody(BuildContext context, ReviewStoreController store) {
    if (store.isLoading && store.reviews.isEmpty) {
      return const _ReviewerLoading();
    }
    if (store.loadError != null && store.reviews.isEmpty) {
      return _ReviewerError(
        message: store.loadError!,
        onRetry: () => store.loadReviews(),
      );
    }
    if (store.reviews.isEmpty) {
      return const _ReviewerEmpty();
    }
    final Review? selected = _findSelected(store.reviews);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          width: _kReviewListPaneWidth,
          child: ReviewListPane(
            reviews: store.reviews,
            selectedReviewId: _selectedReviewId,
            onSelectReview: _selectReview,
          ),
        ),
        const SizedBox(width: kSpace24),
        Expanded(
          child: selected == null
              ? const _DetailEmptyPlaceholder()
              : ReviewerDetailView(
                  key: ValueKey<String>(selected.id),
                  review: selected,
                ),
        ),
      ],
    );
  }
}

class _ReviewerLoading extends StatelessWidget {
  const _ReviewerLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _ReviewerError extends StatelessWidget {
  const _ReviewerError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.appColorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline_rounded,
              size: 36,
              color: scheme.error,
            ),
            const SizedBox(height: kSpace12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: kSpace16),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewerEmpty extends StatelessWidget {
  const _ReviewerEmpty();

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.rate_review_outlined,
              size: 40,
              color: context.appColorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: kSpace16),
            Text(
              'No reviews yet',
              textAlign: TextAlign.center,
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: kSpace8),
            Text(
              'Corrections, comments, and likes you give the AI on '
              'experiment plans will collect here automatically.',
              textAlign: TextAlign.center,
              style: context.scientist.bodySecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailEmptyPlaceholder extends StatelessWidget {
  const _DetailEmptyPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Select a review to inspect',
        style: context.scientist.bodySecondary,
      ),
    );
  }
}

/// Helper used by both the list tile and the detail header.
String describeReview(Review review) {
  if (review is CorrectionReview) {
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
