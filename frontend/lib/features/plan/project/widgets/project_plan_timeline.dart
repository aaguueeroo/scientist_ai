import 'package:flutter/material.dart' hide Material, Step;

import '../../../../core/app_constants.dart';
import '../../../../core/theme/theme_context.dart';
import '../../../../models/experiment_plan.dart';
import '../../../../models/project.dart';
import '../../../../ui/app_surface.dart';
import '../../widgets/plan_timeline_dag_canvas.dart';
import '../../widgets/timeline_dag_layout.dart';

/// Project-mode timeline: same DAG layout as [PlanTimeline] but each step
/// node renders one of three states based on completion.
class ProjectPlanTimeline extends StatelessWidget {
  const ProjectPlanTimeline({
    super.key,
    required this.project,
  });

  final Project project;

  String _formatDuration(Duration value) {
    if (value.inDays > 0) {
      if (value.inHours % 24 == 0) {
        return '${value.inDays} d';
      }
      final int hours = value.inHours.remainder(24);
      return '${value.inDays} d $hours h';
    }
    return '${value.inHours} h';
  }

  @override
  Widget build(BuildContext context) {
    final List<Step> steps = project.plan.timePlan.steps;
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
              return Text(
                step.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: step.isMilestone
                    ? textTheme.labelMedium!.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      )
                    : textTheme.labelMedium,
              );
            },
            subLabelBuilder: (BuildContext ctx, Step step, int index) {
              if (step.isMilestone) {
                return Text(
                  step.milestone!,
                  textAlign: TextAlign.center,
                  style: textTheme.labelSmall!.copyWith(
                    color: scheme.primary,
                  ),
                );
              }
              return Text(
                _formatDuration(step.duration),
                textAlign: TextAlign.center,
                style: context.scientist.numericBody.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              );
            },
            nodeBuilder:
                (BuildContext ctx, Step step, int index, Rect nodeRect) {
              return _ProjectDagStepNode(
                step: step,
                scheme: scheme,
                isCompleted: project.isStepCompleted(step.id),
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

class _ProjectDagStepNode extends StatelessWidget {
  const _ProjectDagStepNode({
    required this.step,
    required this.scheme,
    required this.isCompleted,
  });

  final Step step;
  final ColorScheme scheme;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    if (step.isMilestone) {
      return Center(
        child: _ProjectMilestoneNode(
          step: step,
          scheme: scheme,
          isCompleted: isCompleted,
        ),
      );
    }
    if (isCompleted) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(kRadius),
          color: scheme.primary,
          border: Border.all(color: scheme.primary),
        ),
        child: Center(
          child: Icon(
            Icons.check_rounded,
            size: 14,
            color: scheme.onPrimary,
          ),
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kRadius),
        color: scheme.surface,
        border: Border.all(color: scheme.primary, width: 1.5),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _ProjectMilestoneNode extends StatelessWidget {
  const _ProjectMilestoneNode({
    required this.step,
    required this.scheme,
    required this.isCompleted,
  });

  final Step step;
  final ColorScheme scheme;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final Color baseColor = scheme.primary;
    return Tooltip(
      message: step.milestone!,
      preferBelow: true,
      verticalOffset: 14,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: baseColor.withValues(alpha: 0.4)),
      ),
      textStyle: Theme.of(context).textTheme.bodySmall!.copyWith(
            color: scheme.onSurface,
          ),
      waitDuration: const Duration(milliseconds: 300),
      child: Container(
        width: kPlanTimelineMilestoneSize,
        height: kPlanTimelineMilestoneSize,
        decoration: BoxDecoration(
          color: isCompleted ? baseColor : scheme.surface,
          shape: BoxShape.circle,
          border: Border.all(color: baseColor, width: 1.5),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: baseColor.withValues(alpha: isCompleted ? 0.35 : 0.15),
              blurRadius: 6,
            ),
          ],
        ),
        child: Center(
          child: Icon(
            isCompleted ? Icons.check_rounded : Icons.flag_rounded,
            size: 12,
            color: isCompleted ? scheme.onPrimary : baseColor,
          ),
        ),
      ),
    );
  }
}
