import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Material, Step;
import 'package:provider/provider.dart';

import '../../../../core/app_constants.dart';
import '../../../../core/theme/theme_context.dart';
import '../../../../models/experiment_plan.dart';
import '../../../../ui/app_surface.dart';
import '../correction_format.dart';
import '../plan_correction_controller.dart';
import 'inline_editable_text.dart';

const double _kInsertChipSize = 22;
const double _kInsertChipIconSize = 14;

class EditablePlanTimeline extends StatelessWidget {
  const EditablePlanTimeline({super.key});

  @override
  Widget build(BuildContext context) {
    final PlanCorrectionController controller =
        context.watch<PlanCorrectionController>();
    final List<Step> steps = controller.draft.timePlan.steps;
    if (steps.isEmpty) {
      return _EmptyEditableTimeline(onAdd: controller.appendStep);
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
                  child: InlineEditableText(
                    value: step.name,
                    expandHorizontally: true,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    hintText: 'Step name',
                    style: step.isMilestone
                        ? textTheme.labelMedium!.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          )
                        : textTheme.labelMedium,
                    onSubmitted: (String text) {
                      controller.updateStep(index, step.copyWith(name: text));
                    },
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
                child: _EditableTimelineNodeSegment(
                  index: index,
                  step: steps[index],
                  hasLeftLine: index > 0,
                  hasRightLine: index < steps.length - 1,
                  onInsertAfter: () => controller.insertStepAt(index),
                  onInsertBefore: () => controller.insertStepAt(index - 1),
                  onRemove: () => controller.removeStep(index),
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
                child: _EditableTimelineDurationLabel(
                  step: step,
                  onChanged: (Duration value) {
                    controller.updateStep(
                      index,
                      step.copyWith(duration: value),
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  int _flexForStep(Step step) {
    return step.duration.inMilliseconds > 0
        ? step.duration.inMilliseconds
        : 1;
  }
}

class _EditableTimelineDurationLabel extends StatelessWidget {
  const _EditableTimelineDurationLabel({
    required this.step,
    required this.onChanged,
  });

  final Step step;
  final ValueChanged<Duration> onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.appColorScheme;
    final TextStyle baseStyle = context.scientist.numericBody.copyWith(
      color: scheme.onSurfaceVariant,
    );
    if (step.isMilestone) {
      return Text(
        step.milestone!,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall!.copyWith(
              color: scheme.primary,
            ),
      );
    }
    return InlineEditableText(
      value: formatDurationLabel(step.duration),
      expandHorizontally: true,
      style: baseStyle,
      textAlign: TextAlign.center,
      maxLines: 1,
      hintText: '0 h',
      onSubmitted: (String text) {
        final Duration? parsed = parseDurationLabel(text);
        if (parsed != null) {
          onChanged(parsed);
        }
      },
    );
  }
}

class _EditableTimelineNodeSegment extends StatelessWidget {
  const _EditableTimelineNodeSegment({
    required this.index,
    required this.step,
    required this.hasLeftLine,
    required this.hasRightLine,
    required this.onInsertAfter,
    required this.onInsertBefore,
    required this.onRemove,
  });

  final int index;
  final Step step;
  final bool hasLeftLine;
  final bool hasRightLine;
  final VoidCallback onInsertAfter;
  final VoidCallback onInsertBefore;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: hasLeftLine
              ? _TimelineInsertLine(onInsert: onInsertBefore)
              : const SizedBox.shrink(),
        ),
        _HoverDeleteNode(step: step, onRemove: onRemove),
        Expanded(
          child: hasRightLine
              ? _TimelineInsertLine(onInsert: onInsertAfter)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _TimelineInsertLine extends StatefulWidget {
  const _TimelineInsertLine({required this.onInsert});

  final VoidCallback onInsert;

  @override
  State<_TimelineInsertLine> createState() => _TimelineInsertLineState();
}

class _TimelineInsertLineState extends State<_TimelineInsertLine> {
  bool _isHovered = false;
  double? _cursorX;

  void _handleEnter(PointerEnterEvent event) {
    setState(() {
      _isHovered = true;
      _cursorX = event.localPosition.dx;
    });
  }

  void _handleHover(PointerHoverEvent event) {
    setState(() => _cursorX = event.localPosition.dx);
  }

  void _handleExit(PointerExitEvent _) {
    setState(() {
      _isHovered = false;
      _cursorX = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color lineColor = context.scientist.timelineConnector;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: _handleEnter,
      onHover: _handleHover,
      onExit: _handleExit,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onInsert,
        child: SizedBox(
          height: _kInsertChipSize,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double maxX = constraints.maxWidth;
              final double clampedX = (_cursorX ?? maxX / 2).clamp(
                _kInsertChipSize / 2,
                maxX <= 0 ? _kInsertChipSize / 2 : maxX - _kInsertChipSize / 2,
              );
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: <Widget>[
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      height: kPlanTimelineLineThickness,
                      color: lineColor,
                    ),
                  ),
                  if (_isHovered)
                    Positioned(
                      left: clampedX - _kInsertChipSize / 2,
                      top: 0,
                      child: const _InsertChip(),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _InsertChip extends StatelessWidget {
  const _InsertChip();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.appColorScheme;
    return Container(
      width: _kInsertChipSize,
      height: _kInsertChipSize,
      decoration: BoxDecoration(
        color: scheme.primary,
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.35),
            blurRadius: 6,
          ),
        ],
      ),
      child: Icon(
        Icons.add,
        size: _kInsertChipIconSize,
        color: scheme.onPrimary,
      ),
    );
  }
}

class _HoverDeleteNode extends StatefulWidget {
  const _HoverDeleteNode({
    required this.step,
    required this.onRemove,
  });

  final Step step;
  final VoidCallback onRemove;

  @override
  State<_HoverDeleteNode> createState() => _HoverDeleteNodeState();
}

class _HoverDeleteNodeState extends State<_HoverDeleteNode> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.appColorScheme;
    final bool isMilestone = widget.step.isMilestone;
    final double size = isMilestone
        ? kPlanTimelineMilestoneSize
        : kPlanTimelineNodeDiameter;
    final Color baseColor =
        isMilestone ? scheme.primary : scheme.primary;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onRemove,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: _isHovered ? kPlanTimelineMilestoneSize : size,
          height: _isHovered ? kPlanTimelineMilestoneSize : size,
          decoration: BoxDecoration(
            color: _isHovered ? scheme.error : baseColor,
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: (_isHovered ? scheme.error : baseColor)
                    .withValues(alpha: _isHovered ? 0.5 : 0.25),
                blurRadius: _isHovered ? 10 : 6,
                spreadRadius: _isHovered ? 2 : 0,
              ),
            ],
          ),
          child: _isHovered
              ? Icon(
                  Icons.delete_outline_rounded,
                  size: 12,
                  color: scheme.onError,
                )
              : (isMilestone
                  ? Icon(
                      Icons.flag_rounded,
                      size: 12,
                      color: scheme.onPrimary,
                    )
                  : null),
        ),
      ),
    );
  }
}

class _EmptyEditableTimeline extends StatelessWidget {
  const _EmptyEditableTimeline({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.symmetric(
        horizontal: kSpace24,
        vertical: kSpace24,
      ),
      child: Center(
        child: TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add the first step'),
        ),
      ),
    );
  }
}
