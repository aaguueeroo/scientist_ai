import 'package:flutter/material.dart' hide Material, Step;

import '../../../../core/app_constants.dart';
import '../../../../core/theme/theme_context.dart';
import '../../../../models/experiment_plan.dart';
import '../../../../models/project.dart';
import '../../../../ui/app_surface.dart';

/// Project-mode timeline: same layout as `PlanTimeline` but each step
/// node renders one of three states based on completion:
///  - not completed: outlined circle.
///  - completed: filled circle with a check mark.
///  - milestone: pill-style flag node (filled = primary, outlined =
///    primary border w/ surface fill); completed milestones overlay a
///    small check mark.
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

  int _flexForStep(Step step) {
    return step.duration.inMilliseconds > 0
        ? step.duration.inMilliseconds
        : 1;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List<Widget>.generate(steps.length, (int index) {
              final Step step = steps[index];
              return Expanded(
                flex: _flexForStep(step),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kSpace4),
                  child: Text(
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
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: kSpace12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List<Widget>.generate(steps.length, (int index) {
              final Step step = steps[index];
              return Expanded(
                flex: _flexForStep(step),
                child: _ProjectTimelineNodeSegment(
                  step: step,
                  scheme: scheme,
                  isCompleted: project.isStepCompleted(step.id),
                  hasLeftSegment: index > 0,
                  hasRightSegment: index < steps.length - 1,
                ),
              );
            }),
          ),
          const SizedBox(height: kSpace8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List<Widget>.generate(steps.length, (int index) {
              final Step step = steps[index];
              return Expanded(
                flex: _flexForStep(step),
                child: step.isMilestone
                    ? Text(
                        step.milestone!,
                        textAlign: TextAlign.center,
                        style: textTheme.labelSmall!.copyWith(
                          color: scheme.primary,
                        ),
                      )
                    : Text(
                        _formatDuration(step.duration),
                        textAlign: TextAlign.center,
                        style: context.scientist.numericBody.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _ProjectTimelineNodeSegment extends StatelessWidget {
  const _ProjectTimelineNodeSegment({
    required this.step,
    required this.scheme,
    required this.isCompleted,
    required this.hasLeftSegment,
    required this.hasRightSegment,
  });

  final Step step;
  final ColorScheme scheme;
  final bool isCompleted;
  final bool hasLeftSegment;
  final bool hasRightSegment;

  @override
  Widget build(BuildContext context) {
    final Color lineColor = context.scientist.timelineConnector;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: hasLeftSegment
              ? Container(
                  height: kPlanTimelineLineThickness,
                  color: lineColor,
                )
              : const SizedBox.shrink(),
        ),
        step.isMilestone
            ? _MilestoneNode(
                step: step,
                scheme: scheme,
                isCompleted: isCompleted,
              )
            : _StepCircleNode(
                scheme: scheme,
                isCompleted: isCompleted,
              ),
        Expanded(
          child: hasRightSegment
              ? Container(
                  height: kPlanTimelineLineThickness,
                  color: lineColor,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _StepCircleNode extends StatelessWidget {
  const _StepCircleNode({
    required this.scheme,
    required this.isCompleted,
  });

  final ColorScheme scheme;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    if (isCompleted) {
      return Container(
        width: kPlanTimelineMilestoneSize,
        height: kPlanTimelineMilestoneSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.primary,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.check_rounded,
          size: 12,
          color: scheme.onPrimary,
        ),
      );
    }
    return Container(
      width: kPlanTimelineMilestoneSize,
      height: kPlanTimelineMilestoneSize,
      decoration: BoxDecoration(
        color: scheme.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: scheme.primary,
          width: 1.5,
        ),
      ),
    );
  }
}

class _MilestoneNode extends StatelessWidget {
  const _MilestoneNode({
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
