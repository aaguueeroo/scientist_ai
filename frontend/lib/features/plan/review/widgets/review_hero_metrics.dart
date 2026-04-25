import 'package:flutter/material.dart' hide Material, Step;

import '../../../../core/app_constants.dart';
import '../../../../core/theme/theme_context.dart';
import '../../../review/widgets/focus_highlight_container.dart';
import '../models/change_target.dart';
import '../models/review_section.dart';
import 'hero_metric_feedback_overlay.dart';
import 'suggestion_aware_text.dart';

class ReviewHeroMetrics extends StatelessWidget {
  const ReviewHeroMetrics({
    super.key,
    required this.totalTimeLabel,
    required this.totalBudgetLabel,
  });

  final String totalTimeLabel;
  final String totalBudgetLabel;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color iconColor = context.appColorScheme.onSurfaceVariant;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        FocusHighlightContainer(
          section: ReviewSection.totalTime,
          child: HeroMetricFeedbackOverlay(
            section: ReviewSection.totalTime,
            child: _MetricCluster(
              icon: Icons.hourglass_bottom_rounded,
              iconColor: iconColor,
              label: 'TOTAL TIME',
              valueWidget: SuggestionAwareText(
                target: const TotalDurationTarget(),
                text: totalTimeLabel,
                style: textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              labelStyle: textTheme.labelSmall,
            ),
          ),
        ),
        const SizedBox(width: kSpace40),
        FocusHighlightContainer(
          section: ReviewSection.budget,
          child: HeroMetricFeedbackOverlay(
            section: ReviewSection.budget,
            child: _MetricCluster(
              icon: Icons.attach_money_rounded,
              iconColor: iconColor,
              label: 'BUDGET',
              valueWidget: SuggestionAwareText(
                target: const BudgetTotalTarget(),
                text: totalBudgetLabel,
                style: textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              labelStyle: textTheme.labelSmall,
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricCluster extends StatelessWidget {
  const _MetricCluster({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.valueWidget,
    required this.labelStyle,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final Widget valueWidget;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 28, color: iconColor),
            const SizedBox(width: kSpace8),
            valueWidget,
          ],
        ),
        const SizedBox(height: kSpace4),
        Text(label, style: labelStyle),
      ],
    );
  }
}
