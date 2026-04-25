import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/app_constants.dart';
import '../models/review_section.dart';
import '../plan_review_controller.dart';
import 'feedback_buttons.dart';

/// Wraps a hero metric (total time / budget) and reveals a small
/// thumbs row beneath it when the user hovers, in viewing mode only.
class HeroMetricFeedbackOverlay extends StatefulWidget {
  const HeroMetricFeedbackOverlay({
    super.key,
    required this.section,
    required this.child,
  });

  final ReviewSection section;
  final Widget child;

  @override
  State<HeroMetricFeedbackOverlay> createState() =>
      _HeroMetricFeedbackOverlayState();
}

class _HeroMetricFeedbackOverlayState extends State<HeroMetricFeedbackOverlay> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final PlanReviewController controller =
        context.watch<PlanReviewController>();
    final bool canShow = controller.mode == ReviewMode.viewing &&
        !controller.isHistoricalView;
    return MouseRegion(
      onEnter: (_) {
        if (canShow) setState(() => _isHovered = true);
      },
      onExit: (_) => setState(() => _isHovered = false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          widget.child,
          const SizedBox(height: kSpace8),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            opacity: canShow && _isHovered ? 1 : 0,
            child: IgnorePointer(
              ignoring: !(canShow && _isHovered),
              child: FeedbackButtons(
                value: controller.sectionFeedback[widget.section]?.polarity,
                onChanged: (polarity) =>
                    controller.setSectionFeedback(widget.section, polarity),
                compact: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
