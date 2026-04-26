import 'package:flutter/material.dart' hide Material, Step;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/review_store_controller.dart';
import '../../core/app_constants.dart';
import '../../core/theme/theme_context.dart';
import 'models/review.dart';
import 'reviewer_detail_view.dart';

/// Top-level Reviewer surface: experiment plan for the selected review
/// (from `?reviewId=`) in the main area; list lives in [Sidebar].
class ReviewerScreen extends StatelessWidget {
  const ReviewerScreen({super.key});

  static Review? _reviewForId(List<Review> reviews, String? reviewId) {
    if (reviewId == null) return null;
    for (final Review r in reviews) {
      if (r.id == reviewId) return r;
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
    final String? reviewId =
        GoRouterState.of(context).uri.queryParameters['reviewId'];
    final Review? selected = _reviewForId(store.reviews, reviewId);
    if (selected == null) {
      return const _DetailEmptyPlaceholder();
    }
    return ReviewerDetailView(
      key: ValueKey<String>(selected.id),
      review: selected,
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
              'Corrections, comments, and feedback you give Marie on '
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
