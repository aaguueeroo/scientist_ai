import 'package:flutter/material.dart';

import '../../../core/app_constants.dart';
import '../../../core/theme/theme_context.dart';

class PlanHeroMetrics extends StatelessWidget {
  const PlanHeroMetrics({
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
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.hourglass_bottom_rounded, size: 28, color: iconColor),
                const SizedBox(width: kSpace8),
                Text(
                  totalTimeLabel,
                  style: textTheme.displaySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            const SizedBox(height: kSpace4),
            Text('TOTAL TIME', style: textTheme.labelSmall),
          ],
        ),
        const SizedBox(width: kSpace40),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.attach_money_rounded, size: 28, color: iconColor),
                const SizedBox(width: kSpace8),
                Text(
                  totalBudgetLabel,
                  style: textTheme.displaySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            const SizedBox(height: kSpace4),
            Text('BUDGET', style: textTheme.labelSmall),
          ],
        ),
      ],
    );
  }
}
