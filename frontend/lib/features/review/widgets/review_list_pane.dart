import 'package:flutter/material.dart' hide Material, Step;

import '../../../core/app_constants.dart';
import '../../../core/theme/theme_context.dart';
import '../models/review.dart';
import 'review_list_tile.dart';

/// Scrollable list of every persisted review, grouped under a single
/// header. Used by [Sidebar] in reviewer mode (set [embedInSidebar]) and
/// elsewhere as a card-styled pane.
class ReviewListPane extends StatelessWidget {
  const ReviewListPane({
    super.key,
    required this.reviews,
    required this.selectedReviewId,
    required this.onSelectReview,
    this.embedInSidebar = false,
  });

  final List<Review> reviews;
  final String? selectedReviewId;
  final ValueChanged<String> onSelectReview;

  /// When true, omit the elevated surface card so the list sits flush on the
  /// shell sidebar background.
  final bool embedInSidebar;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(
            embedInSidebar ? kSpace24 : kSpace16,
            embedInSidebar ? kSpace4 : kSpace4,
            embedInSidebar ? kSpace24 : kSpace16,
            embedInSidebar ? kSpace8 : kSpace12,
          ),
          child: Text(
            'Reviews (${reviews.length})',
            style: textTheme.labelSmall,
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(
              horizontal: embedInSidebar ? kSpace8 : kSpace8,
            ),
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
    );
    if (embedInSidebar) {
      return Padding(
        padding: const EdgeInsets.only(top: kSpace4),
        child: content,
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: context.appColorScheme.surface,
        borderRadius: BorderRadius.circular(kRadius),
      ),
      padding: const EdgeInsets.symmetric(vertical: kSpace12),
      child: content,
    );
  }
}
