import 'package:flutter/material.dart' hide Material, Step;

import '../../../core/app_constants.dart';
import '../../../core/theme/theme_context.dart';
import '../../plan/review/models/feedback_polarity.dart';
import '../models/review.dart';
import '../review_description.dart' show describeReview;

/// One row in the Reviewer list pane. Displays a kind-specific icon, a
/// short title, and the conversation query as subtitle.
class ReviewListTile extends StatefulWidget {
  const ReviewListTile({
    super.key,
    required this.review,
    required this.isActive,
    required this.onTap,
  });

  final Review review;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<ReviewListTile> createState() => _ReviewListTileState();
}

class _ReviewListTileState extends State<ReviewListTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.appColorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isActive = widget.isActive;
    final Color background = isActive
        ? scheme.primaryContainer
        : (_isHovered
            ? context.scientist.sidebarBackground
            : Colors.transparent);
    final Color foreground = isActive ? scheme.primary : scheme.onSurface;
    final _ReviewIconSpec iconSpec = _iconForReview(widget.review);
    final String title = describeReview(widget.review);
    final String subtitle = (widget.review.query.isNotEmpty)
        ? widget.review.query
        : 'No prompt';
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(
            horizontal: kSpace12,
            vertical: kSpace12,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(kRadius - 2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  iconSpec.icon,
                  size: 16,
                  color: iconSpec.color ?? foreground,
                ),
              ),
              const SizedBox(width: kSpace12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: foreground,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewIconSpec {
  const _ReviewIconSpec(this.icon, [this.color]);
  final IconData icon;
  final Color? color;
}

_ReviewIconSpec _iconForReview(Review review) {
  if (review is CorrectionReview) {
    return const _ReviewIconSpec(Icons.edit_note_rounded);
  }
  if (review is CommentReview) {
    return const _ReviewIconSpec(Icons.chat_bubble_outline_rounded);
  }
  if (review is FeedbackReview) {
    if (review.polarity == FeedbackPolarity.like) {
      return const _ReviewIconSpec(
        Icons.thumb_up_rounded,
        Color(0xFF66BB6A),
      );
    }
    return const _ReviewIconSpec(
      Icons.thumb_down_rounded,
      Color(0xFFEF5350),
    );
  }
  return const _ReviewIconSpec(Icons.rate_review_outlined);
}
