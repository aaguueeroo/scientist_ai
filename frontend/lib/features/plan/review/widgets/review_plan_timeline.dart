import 'package:flutter/material.dart' hide Material, Step;

import '../../../../core/app_constants.dart';
import '../../../../core/theme/theme_context.dart';
import '../../../../models/experiment_plan.dart';
import '../../../../ui/app_surface.dart';
import '../../correction/correction_format.dart';
import '../../widgets/plan_timeline_dag_canvas.dart';
import '../../widgets/timeline_dag_layout.dart';
import '../models/change_target.dart';
import '../models/step_field.dart';
import 'suggestion_aware_text.dart';

/// Read-only timeline that mirrors [PlanTimeline] but routes the step
/// labels and milestone copy through [SuggestionAwareText] so accepted
/// or pending suggestions paint with the right color.
class ReviewPlanTimeline extends StatelessWidget {
  const ReviewPlanTimeline({
    super.key,
    required this.steps,
  });

  final List<Step> steps;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return const SizedBox.shrink();
    }
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = context.appColorScheme;
    return AppSurface(
      padding: const EdgeInsets.symmetric(
        horizontal: kSpace24,
        vertical: kSpace24,
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final TimelineDagLayout layout = computeTimelineDagLayout(steps);
          final TimelineDagPaintMetrics metrics = computeTimelineDagPaintMetrics(
            layout: layout,
            viewportInnerWidth: constraints.maxWidth,
            labelBandHeight: kPlanTimelineDagLabelBandHeight,
            laneRowHeight: kPlanTimelineDagLaneRowHeight,
            subLabelBandHeight: kPlanTimelineDagSubLabelBandHeight,
            minNodeWidth: kPlanTimelineDagMinNodeWidth,
          );
          final Widget graph = PlanTimelineDagCanvas(
            steps: steps,
            metrics: metrics,
            edgeColor: context.scientist.timelineConnector,
            nameLabelBuilder: (BuildContext ctx, Step step, int index) {
              final TextStyle baseStyle = step.isMilestone
                  ? textTheme.labelMedium!.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    )
                  : textTheme.labelMedium!;
              return SuggestionAwareText(
                target: StepFieldTarget(
                  stepId: step.id,
                  field: StepField.name,
                ),
                text: step.name,
                style: baseStyle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              );
            },
            subLabelBuilder: (BuildContext ctx, Step step, int index) {
              if (step.isMilestone) {
                return SuggestionAwareText(
                  target: StepFieldTarget(
                    stepId: step.id,
                    field: StepField.milestone,
                  ),
                  text: step.milestone!,
                  style: textTheme.labelSmall!.copyWith(
                    color: scheme.primary,
                  ),
                  textAlign: TextAlign.center,
                );
              }
              return Text(
                formatDurationLabel(step.duration),
                textAlign: TextAlign.center,
                style: context.scientist.numericBody.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              );
            },
            nodeBuilder:
                (BuildContext ctx, Step step, int index, Rect nodeRect) {
              return _ReviewDagStepNode(
                step: step,
                scheme: scheme,
              );
            },
          );
          if (metrics.contentWidth <= constraints.maxWidth + 0.5) {
            return graph;
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: graph,
          );
        },
      ),
    );
  }
}

class _ReviewDagStepNode extends StatelessWidget {
  const _ReviewDagStepNode({
    required this.step,
    required this.scheme,
  });

  final Step step;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    if (step.isMilestone) {
      return Center(
        child: Container(
          width: kPlanTimelineMilestoneSize,
          height: kPlanTimelineMilestoneSize,
          decoration: BoxDecoration(
            color: scheme.primary,
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.25),
                blurRadius: 6,
              ),
            ],
          ),
          child: Icon(
            Icons.flag_rounded,
            size: 12,
            color: scheme.onPrimary,
          ),
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kRadius),
        color: scheme.primary.withValues(alpha: 0.14),
        border: Border.all(color: scheme.primary),
      ),
      child: const SizedBox.expand(),
    );
  }
}
