import 'package:flutter/material.dart' hide Material, Step;
import 'package:provider/provider.dart';

import '../../../../core/app_constants.dart';
import '../../../../core/theme/theme_context.dart';
import '../../../../models/experiment_plan.dart';
import '../../review/models/change_target.dart';
import '../../review/plan_review_controller.dart';
import '../correction_format.dart';
import 'edit_highlight.dart';
import 'hover_stepper.dart';
import 'inline_editable_text.dart';

class EditableHeroMetrics extends StatelessWidget {
  const EditableHeroMetrics({super.key});

  @override
  Widget build(BuildContext context) {
    final PlanReviewController controller =
        context.watch<PlanReviewController>();
    final ExperimentPlan plan = controller.draft ?? controller.livePlan;
    final Duration duration = plan.timePlan.totalDuration;
    final double total = plan.budget.total;
    final bool isDurationChanged =
        controller.isDraftFieldChanged(const TotalDurationTarget());
    final bool isBudgetChanged =
        controller.isDraftFieldChanged(const BudgetTotalTarget());
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        _MetricCluster(
          icon: Icons.hourglass_bottom_rounded,
          label: 'TOTAL TIME',
          child: _TimeMetric(
            duration: duration,
            isChanged: isDurationChanged,
            onChanged: controller.updateTotalDuration,
          ),
        ),
        const SizedBox(width: kSpace40),
        _MetricCluster(
          icon: Icons.attach_money_rounded,
          label: 'BUDGET',
          child: _BudgetMetric(
            total: total,
            isChanged: isBudgetChanged,
            onChanged: controller.updateBudgetTotal,
          ),
        ),
      ],
    );
  }
}

class _MetricCluster extends StatelessWidget {
  const _MetricCluster({
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color iconColor = context.appColorScheme.onSurfaceVariant;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 28, color: iconColor),
            const SizedBox(width: kSpace8),
            child,
          ],
        ),
        const SizedBox(height: kSpace4),
        Text(label, style: textTheme.labelSmall),
      ],
    );
  }
}

class _TimeMetric extends StatelessWidget {
  const _TimeMetric({
    required this.duration,
    required this.isChanged,
    required this.onChanged,
  });

  final Duration duration;
  final bool isChanged;
  final ValueChanged<Duration> onChanged;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = Theme.of(context).textTheme.displaySmall;
    return HoverStepper(
      tooltipIncrement: 'Add time',
      tooltipDecrement: 'Remove time',
      onIncrement: () {
        onChanged(duration + computeTimeIncrement(duration));
      },
      onDecrement: () {
        final Duration step = computeTimeIncrement(duration);
        final Duration next =
            duration > step ? duration - step : Duration.zero;
        onChanged(next);
      },
      child: InlineEditableText(
        value: formatDurationLabel(duration),
        style: editedTextStyle(style, isChanged: isChanged),
        textAlign: TextAlign.center,
        maxLines: 1,
        hintText: '0 d 0 h',
        onSubmitted: (String text) {
          final Duration? parsed = parseDurationLabel(text);
          if (parsed != null) {
            onChanged(parsed);
          }
        },
      ),
    );
  }
}

class _BudgetMetric extends StatelessWidget {
  const _BudgetMetric({
    required this.total,
    required this.isChanged,
    required this.onChanged,
  });

  final double total;
  final bool isChanged;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = Theme.of(context).textTheme.displaySmall;
    return HoverStepper(
      tooltipIncrement: 'Add budget',
      tooltipDecrement: 'Remove budget',
      onIncrement: () {
        onChanged(total + computeBudgetIncrement(total));
      },
      onDecrement: () {
        final double step = computeBudgetIncrement(total);
        final double next = total > step ? total - step : 0;
        onChanged(next);
      },
      child: InlineEditableText(
        value: formatBudgetLabel(total),
        style: editedTextStyle(style, isChanged: isChanged),
        textAlign: TextAlign.center,
        maxLines: 1,
        hintText: '\$0.00',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onSubmitted: (String text) {
          final double? parsed = parseBudgetLabel(text);
          if (parsed != null) {
            onChanged(parsed);
          }
        },
      ),
    );
  }
}
