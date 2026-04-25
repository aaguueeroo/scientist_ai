import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/app_constants.dart';
import '../../../../core/theme/theme_context.dart';
import '../models/suggestion_batch.dart';
import '../plan_review_controller.dart';
import 'review_action_bar.dart';

/// Top banner shown while a suggestion batch is awaiting review.
/// Disappears with a slide animation when the user accepts or discards.
class PendingBatchBanner extends StatelessWidget {
  const PendingBatchBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final PlanReviewController controller =
        context.watch<PlanReviewController>();
    final SuggestionBatch? batch = controller.pendingBatch;
    final bool show = batch != null && controller.mode == ReviewMode.reviewingPending;
    return AnimatedSlide(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      offset: show ? Offset.zero : const Offset(0, -1.2),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: show ? 1 : 0,
        child: show ? _BannerBody(batch: batch) : const SizedBox.shrink(),
      ),
    );
  }
}

class _BannerBody extends StatelessWidget {
  const _BannerBody({required this.batch});

  final SuggestionBatch batch;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.appColorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final int count = batch.changes.length;
    final String label =
        count == 1 ? '1 suggestion pending review' : '$count suggestions pending review';
    return Container(
      margin: const EdgeInsets.only(bottom: kSpace16),
      padding: const EdgeInsets.symmetric(
        horizontal: kSpace16,
        vertical: kSpace12,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border(
          left: BorderSide(color: batch.color, width: 3),
        ),
      ),
      child: Row(
        children: <Widget>[
          BatchColorChip(color: batch.color, size: 12),
          const SizedBox(width: kSpace12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(label, style: textTheme.titleSmall),
                const SizedBox(height: kSpace4),
                Text(
                  'Original content is shown crossed out. The new content is highlighted in this batch\u0027s color.',
                  style: textTheme.bodySmall?.copyWith(
                    color: context.scientist.onSurfaceFaint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
