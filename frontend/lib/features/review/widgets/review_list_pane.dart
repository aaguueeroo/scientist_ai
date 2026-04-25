import 'package:flutter/material.dart' hide Material, Step;

import '../../../core/app_constants.dart';
import '../../../core/theme/theme_context.dart';
import '../models/review.dart';
import 'review_list_tile.dart';

/// Scrollable list of every persisted review, grouped under a single
/// header. Used by [ReviewerScreen] in the left pane.
class ReviewListPane extends StatelessWidget {
  const ReviewListPane({
    super.key,
    required this.reviews,
    required this.selectedReviewId,
    required this.onSelectReview,
  });

  final List<Review> reviews;
  final String? selectedReviewId;
  final ValueChanged<String> onSelectReview;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: context.appColorScheme.surface,
        borderRadius: BorderRadius.circular(kRadius),
      ),
      padding: const EdgeInsets.symmetric(vertical: kSpace12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              kSpace16,
              kSpace4,
              kSpace16,
              kSpace12,
            ),
            child: Text(
              'Reviews (${reviews.length})',
              style: textTheme.labelSmall,
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: kSpace8),
              itemCount: reviews.length,
              itemBuilder: (BuildContext context, int index) {
                final Review review = reviews[index];
                return ReviewListTile(
                  review: review,
                  isActive: review.id == selectedReviewId,
                  onTap: () => onSelectReview(review.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
