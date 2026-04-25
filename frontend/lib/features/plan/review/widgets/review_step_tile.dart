import 'package:flutter/material.dart' hide Material, Step;
import 'package:provider/provider.dart';

import '../../../../core/app_constants.dart';
import '../../../../core/theme/theme_context.dart';
import '../../../../models/experiment_plan.dart';
import '../../correction/correction_format.dart';
import '../models/change_target.dart';
import '../models/plan_change.dart';
import '../models/step_field.dart';
import '../plan_review_controller.dart';
import 'selectable_plan_text.dart';
import 'suggestion_aware_text.dart';

/// Read-only step tile used in the review body. Renders the step number,
/// name, description and duration with suggestion-aware text. The tile
/// also highlights itself if it was inserted by a pending or accepted
/// batch.
class ReviewStepTile extends StatefulWidget {
  const ReviewStepTile({
    super.key,
    required this.step,
  });

  final Step step;

  @override
  State<ReviewStepTile> createState() => _ReviewStepTileState();
}

class _ReviewStepTileState extends State<ReviewStepTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = context.appColorScheme;
    final PlanReviewController controller =
        context.watch<PlanReviewController>();
    final bool pendingInsert =
        controller.isStepPendingInsert(widget.step.id);
    final StepRemoved? pendingRemoval =
        controller.pendingStepRemovalFor(widget.step.id);
    final bool isPendingRemoved = pendingRemoval != null;
    final Color? acceptedTint = controller.colorForTarget(
      StepFieldTarget(stepId: widget.step.id, field: StepField.name),
    );
    final Color? insertTint =
        pendingInsert ? controller.pendingBatch?.color : acceptedTint;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(kSpace16),
        decoration: BoxDecoration(
          color: _isHovered ? scheme.primaryContainer : scheme.surface,
          borderRadius: BorderRadius.circular(kRadius),
          border: insertTint != null
              ? Border(
                  left: BorderSide(color: insertTint, width: 2),
                )
              : null,
        ),
        child: Opacity(
          opacity: isPendingRemoved ? 0.5 : 1,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _StepNumberBadge(number: widget.step.number),
              const SizedBox(width: kSpace16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SuggestionAwareText(
                      target: StepFieldTarget(
                        stepId: widget.step.id,
                        field: StepField.name,
                      ),
                      text: widget.step.name,
                      style: textTheme.titleMedium,
                    ),
                    if (widget.step.description.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: kSpace4),
                      SelectablePlanText(
                        target: StepFieldTarget(
                          stepId: widget.step.id,
                          field: StepField.description,
                        ),
                        text: widget.step.description,
                        style: context.scientist.bodySecondary,
                      ),
                    ],
                    if (isPendingRemoved)
                      Padding(
                        padding: const EdgeInsets.only(top: kSpace8),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.delete_outline_rounded,
                              size: 14,
                              color: controller.pendingBatch?.color,
                            ),
                            const SizedBox(width: kSpace4),
                            Text(
                              'Marked for removal',
                              style: textTheme.labelSmall?.copyWith(
                                color: controller.pendingBatch?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: kSpace16),
              SuggestionAwareText(
                target: StepFieldTarget(
                  stepId: widget.step.id,
                  field: StepField.duration,
                ),
                text: formatDurationLabel(widget.step.duration),
                style: context.scientist.numericBody.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.right,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepNumberBadge extends StatelessWidget {
  const _StepNumberBadge({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = context.appColorScheme;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(kRadius - 2),
      ),
      child: Text(
        number.toString(),
        style: textTheme.labelMedium?.copyWith(color: scheme.primary),
      ),
    );
  }
}

/// Tile representing a step that was removed by an accepted batch but is
/// being shown in pending review for context. Currently unused (we
/// optimistically apply removals before displaying), kept for future
/// pending-removal tooltips.
class PendingRemovedStepTile extends StatelessWidget {
  const PendingRemovedStepTile({super.key, required this.step});

  final Step step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: kSpace4),
      child: ReviewStepTile(step: step),
    );
  }
}
