import 'package:flutter/material.dart' hide Material, Step;

import '../../../../core/app_constants.dart';
import '../../../../core/theme/theme_context.dart';
import '../../../../models/experiment_plan.dart';
import '../../../../ui/app_surface.dart';
import '../../correction/correction_format.dart';
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

  int _flexForStep(Step step) {
    return step.duration.inMilliseconds > 0
        ? step.duration.inMilliseconds
        : 1;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List<Widget>.generate(steps.length, (int index) {
              final Step step = steps[index];
              final TextStyle baseStyle = step.isMilestone
                  ? textTheme.labelMedium!.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    )
                  : textTheme.labelMedium!;
              return Expanded(
                flex: _flexForStep(step),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kSpace4),
                  child: SuggestionAwareText(
                    target: StepFieldTarget(
                      stepId: step.id,
                      field: StepField.name,
                    ),
                    text: step.name,
                    style: baseStyle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: kSpace12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List<Widget>.generate(steps.length, (int index) {
              return Expanded(
                flex: _flexForStep(steps[index]),
                child: _TimelineNode(
                  step: steps[index],
                  scheme: scheme,
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
                    ? SuggestionAwareText(
                        target: StepFieldTarget(
                          stepId: step.id,
                          field: StepField.milestone,
                        ),
                        text: step.milestone!,
                        style: textTheme.labelSmall!.copyWith(
                          color: scheme.primary,
                        ),
                        textAlign: TextAlign.center,
                      )
                    : Text(
                        formatDurationLabel(step.duration),
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

class _TimelineNode extends StatelessWidget {
  const _TimelineNode({
    required this.step,
    required this.scheme,
    required this.hasLeftSegment,
    required this.hasRightSegment,
  });

  final Step step;
  final ColorScheme scheme;
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
            ? Container(
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
              )
            : Container(
                width: kPlanTimelineNodeDiameter,
                height: kPlanTimelineNodeDiameter,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
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
