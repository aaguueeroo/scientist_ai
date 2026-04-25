import 'package:flutter/material.dart' hide Material, Step;

import '../../../core/app_constants.dart';
import '../../../core/theme/theme_context.dart';
import '../../../models/experiment_plan.dart';
import '../../../ui/app_surface.dart';

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
              return Expanded(
                flex: _flexForStep(steps[index]),
                child: _TimelineNodeSegment(
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

class _TimelineNodeSegment extends StatelessWidget {
  const _TimelineNodeSegment({
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
            ? _MilestoneNode(step: step, scheme: scheme)
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
