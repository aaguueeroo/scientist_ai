import 'package:flutter/material.dart' hide Material, Step;
import 'package:provider/provider.dart';

import '../../../../core/app_constants.dart';
import '../../../../core/theme/theme_context.dart';
import '../../../../models/experiment_plan.dart';
import '../../review/models/step_field.dart';
import '../../review/plan_review_controller.dart';
import '../correction_format.dart';
import 'edit_highlight.dart';
import 'inline_editable_text.dart';

class EditableStepTile extends StatefulWidget {
  const EditableStepTile({
    super.key,
    required this.step,
    required this.onChanged,
    required this.onRemove,
  });

  final Step step;
  final ValueChanged<Step> onChanged;
  final VoidCallback onRemove;

  @override
  State<EditableStepTile> createState() => _EditableStepTileState();
}

class _EditableStepTileState extends State<EditableStepTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = context.appColorScheme;
    final PlanReviewController controller =
        context.watch<PlanReviewController>();
    final bool isInserted =
        controller.isStepInsertedInDraft(widget.step.id);
    final Set<StepField> changedFields =
        controller.draftChangedStepFields(widget.step.id);
    final EditChangeKind kind = isInserted
        ? EditChangeKind.inserted
        : (changedFields.isEmpty
            ? EditChangeKind.unchanged
            : EditChangeKind.edited);
    final bool nameChanged =
        isInserted || changedFields.contains(StepField.name);
    final bool descriptionChanged =
        isInserted || changedFields.contains(StepField.description);
    final bool durationChanged =
        isInserted || changedFields.contains(StepField.duration);
    return EditedContainerHighlight(
      kind: kind,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(kSpace16),
          decoration: BoxDecoration(
            color: _isHovered && kind == EditChangeKind.unchanged
                ? scheme.primaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(kRadius),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _StepNumberBadge(number: widget.step.number),
              const SizedBox(width: kSpace16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    InlineEditableText(
                      value: widget.step.name,
                      expandHorizontally: true,
                      style: editedTextStyle(
                        textTheme.titleMedium,
                        isChanged: nameChanged,
                      ),
                      maxLines: 2,
                      hintText: 'Step name',
                      onSubmitted: (String text) {
                        widget.onChanged(widget.step.copyWith(name: text));
                      },
                    ),
                    const SizedBox(height: kSpace4),
                    InlineEditableText(
                      value: widget.step.description,
                      expandHorizontally: true,
                      style: editedTextStyle(
                        context.scientist.bodySecondary,
                        isChanged: descriptionChanged,
                      ),
                      maxLines: null,
                      minLines: 1,
                      hintText: 'Step description',
                      placeholderWhenEmpty: 'Add a description',
                      onSubmitted: (String text) {
                        widget.onChanged(
                          widget.step.copyWith(description: text),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: kSpace16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  InlineEditableText(
                    value: formatDurationLabel(widget.step.duration),
                    style: editedTextStyle(
                      context.scientist.numericBody.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      isChanged: durationChanged,
                    ),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    hintText: '0 h',
                    onSubmitted: (String text) {
                      final Duration? parsed = parseDurationLabel(text);
                      if (parsed != null) {
                        widget.onChanged(
                          widget.step.copyWith(duration: parsed),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: kSpace4),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: _isHovered ? 1 : 0,
                    child: IgnorePointer(
                      ignoring: !_isHovered,
                      child: _StepDeleteButton(onPressed: widget.onRemove),
                    ),
                  ),
                ],
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
        style: textTheme.labelMedium?.copyWith(
          color: scheme.primary,
        ),
      ),
    );
  }
}

class _StepDeleteButton extends StatefulWidget {
  const _StepDeleteButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_StepDeleteButton> createState() => _StepDeleteButtonState();
}

class _StepDeleteButtonState extends State<_StepDeleteButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.appColorScheme;
    return Tooltip(
      message: 'Remove step',
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(kSpace4),
            decoration: BoxDecoration(
              color: _isHovered
                  ? scheme.error.withValues(alpha: 0.16)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(kRadius - 2),
            ),
            child: Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: _isHovered ? scheme.error : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class AddStepTile extends StatefulWidget {
  const AddStepTile({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<AddStepTile> createState() => _AddStepTileState();
}

class _AddStepTileState extends State<AddStepTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.appColorScheme;
    final TextStyle? labelStyle = Theme.of(context).textTheme.labelMedium;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: kSpace16,
            vertical: kSpace16,
          ),
          decoration: BoxDecoration(
            color:
                _isHovered ? scheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(kRadius),
            border: Border.all(
              color: _isHovered
                  ? scheme.primary.withValues(alpha: 0.4)
                  : context.scientist.timelineConnector,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.add,
                size: 16,
                color: _isHovered ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: kSpace8),
              Text(
                'Add step',
                style: labelStyle?.copyWith(
                  color: _isHovered
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
