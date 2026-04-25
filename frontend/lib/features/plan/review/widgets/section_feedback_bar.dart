import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/app_constants.dart';
import '../../../../core/theme/theme_context.dart';
import '../models/review_section.dart';
import '../plan_review_controller.dart';
import 'feedback_buttons.dart';

/// "Was this helpful?" affordance shown beneath each major review section.
/// Reads / writes through the [PlanReviewController].
class SectionFeedbackBar extends StatelessWidget {
  const SectionFeedbackBar({
    super.key,
    required this.section,
    this.label = 'Was this helpful?',
    this.alignment = MainAxisAlignment.end,
  });

  final ReviewSection section;
  final String label;
  final MainAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final PlanReviewController controller =
        context.watch<PlanReviewController>();
    if (controller.isHistoricalView) {
      return const SizedBox.shrink();
    }
    final TextStyle? labelStyle = Theme.of(context).textTheme.labelSmall;
    return Padding(
      padding: const EdgeInsets.only(top: kSpace8),
      child: Row(
        mainAxisAlignment: alignment,
        children: <Widget>[
          if (alignment != MainAxisAlignment.start) const Spacer(),
          Text(
            label,
            style: labelStyle?.copyWith(
              color: context.scientist.onSurfaceFaint,
            ),
          ),
          const SizedBox(width: kSpace8),
          FeedbackButtons(
            value: controller.sectionFeedback[section]?.polarity,
            onChanged: (polarity) =>
                controller.setSectionFeedback(section, polarity),
            compact: true,
          ),
          if (alignment == MainAxisAlignment.start) const Spacer(),
        ],
      ),
    );
  }
}
