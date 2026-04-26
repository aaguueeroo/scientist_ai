import 'package:flutter/material.dart' hide Material, Step;

import '../../../core/app_constants.dart';
import '../../../core/theme/theme_context.dart';
import '../../../models/experiment_plan.dart';
import '../../../ui/app_surface.dart';
import 'plan_timeline_dag_canvas.dart';
import 'timeline_dag_layout.dart';

class PlanTimeline extends StatelessWidget {
  const PlanTimeline({
    super.key,
    required this.steps,
  });

  final List<Step> steps;

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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall!.copyWith(
                    color: scheme.primary,
                  ),
                );
              }
              return Text(
                _formatDuration(step.duration),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.scientist.numericBody.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              );
            },
            nodeBuilder:
                (BuildContext ctx, Step step, int index, Rect nodeRect) {
              return _PlanDagStepNode(
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

class _PlanDagStepNode extends StatelessWidget {
  const _PlanDagStepNode({
    required this.step,
    required this.scheme,
  });

  final Step step;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    if (step.isMilestone) {
      return Center(
        child: _MilestoneNode(step: step, scheme: scheme),
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

class _MilestoneNode extends StatefulWidget {
  const _MilestoneNode({
    required this.step,
    required this.scheme,
  });

  final Step step;
  final ColorScheme scheme;

  @override
  State<_MilestoneNode> createState() => _MilestoneNodeState();
}

class _MilestoneNodeState extends State<_MilestoneNode> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final Color baseColor = widget.scheme.primary;
    final Color hoverColor =
        Color.lerp(baseColor, Colors.white, 0.2) ?? baseColor;
    return Tooltip(
      message: widget.step.milestone!,
      preferBelow: true,
      verticalOffset: 14,
      decoration: BoxDecoration(
        color: widget.scheme.surface,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: baseColor.withValues(alpha: 0.4)),
      ),
      textStyle: Theme.of(context).textTheme.bodySmall!.copyWith(
            color: widget.scheme.onSurface,
          ),
      waitDuration: const Duration(milliseconds: 300),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: kPlanTimelineMilestoneSize,
          height: kPlanTimelineMilestoneSize,
          decoration: BoxDecoration(
            color: _isHovered ? hoverColor : baseColor,
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: baseColor.withValues(alpha: _isHovered ? 0.5 : 0.25),
                blurRadius: _isHovered ? 10 : 6,
                spreadRadius: _isHovered ? 2 : 0,
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.flag_rounded,
              size: 12,
              color: widget.scheme.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
