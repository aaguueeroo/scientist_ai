import 'package:flutter/material.dart' hide Material, Step;
import 'package:provider/provider.dart';

import '../../../../controllers/projects_controller.dart';
import '../../../../core/app_constants.dart';
import '../../../../core/app_toasts.dart';
import '../../../../core/theme/theme_context.dart';
import '../../../../models/experiment_plan.dart';
import '../../../../models/project.dart';
import '../../../../models/user_role.dart';
import '../services/project_file_picker.dart';
import 'project_attachment_row.dart';

/// Step row used inside a project plan view. Adapts to the active role:
///  - lab scientist: leading completion checkbox + "Submit material"
///    button + editable list of attachments below the row.
///  - funder: read-only completion indicator + downloadable attachments
///    revealed when the row is expanded.
class ProjectStepTile extends StatefulWidget {
  const ProjectStepTile({
    super.key,
    required this.project,
    required this.step,
    required this.role,
    this.filePicker = const ProjectFilePicker(),
  });

  final Project project;
  final Step step;
  final UserRole role;
  final ProjectFilePicker filePicker;

  @override
  State<ProjectStepTile> createState() => _ProjectStepTileState();
}

class _ProjectStepTileState extends State<ProjectStepTile> {
  bool _isExpanded = false;
  bool _isHovered = false;
  bool _isPicking = false;

  String _formatDuration(Duration value) {
    if (value.inDays > 0 && value.inHours % 24 == 0) {
      return '${value.inDays} days';
    }
    if (value.inDays > 0) {
      return '${value.inDays} d ${value.inHours.remainder(24)} h';
    }
    return '${value.inHours} hours';
  }

  String _shortDescription(String description) {
    final String trimmed = description.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final List<String> sentences = trimmed.split(RegExp(r'(?<=[.!?])\s+'));
    return sentences.first;
  }

  Future<void> _pickAttachment() async {
    if (_isPicking) {
      return;
    }
    setState(() => _isPicking = true);
    final PickAttachmentResult outcome =
        await widget.filePicker.pickAttachment();
    if (!mounted) {
      return;
    }
    setState(() => _isPicking = false);
    final ProjectsController projects = context.read<ProjectsController>();
    switch (outcome) {
      case PickedAttachment(attachment: final ProjectAttachment a):
        projects.addAttachment(
          projectId: widget.project.id,
          stepId: widget.step.id,
          attachment: a,
        );
        setState(() => _isExpanded = true);
        showAppToast(
          context,
          message: 'Attached "${a.fileName}".',
          variant: AppToastVariant.success,
          autoCloseDuration: const Duration(seconds: 2),
        );
      case PickCancelled():
        // No-op when the user cancels.
        break;
      case PickFailed(message: final String message):
        showAppToast(
          context,
          message: message,
          variant: AppToastVariant.error,
        );
    }
  }

  void _toggleCompletion() {
    context.read<ProjectsController>().toggleStepCompletion(
          projectId: widget.project.id,
          stepId: widget.step.id,
        );
  }

  void _removeAttachment(ProjectAttachment attachment) {
    context.read<ProjectsController>().removeAttachment(
          projectId: widget.project.id,
          stepId: widget.step.id,
          attachmentId: attachment.id,
        );
  }

  void _mockDownload(ProjectAttachment attachment) {
    showAppToast(
      context,
      message: 'Download started for ${attachment.fileName}.',
      autoCloseDuration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = context.appColorScheme;
    final String shortText = _shortDescription(widget.step.description);
    final bool isCompleted =
        widget.project.isStepCompleted(widget.step.id);
    final List<ProjectAttachment> attachments =
        widget.project.attachmentsFor(widget.step.id);
    final bool isLabScientist = widget.role == UserRole.labScientist;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _isExpanded = !_isExpanded),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(kSpace16),
          decoration: BoxDecoration(
            color: _isHovered ? scheme.primaryContainer : scheme.surface,
            borderRadius: BorderRadius.circular(kRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _LeadingCompletion(
                    isCompleted: isCompleted,
                    isInteractive: isLabScientist,
                    onTap: _toggleCompletion,
                  ),
                  const SizedBox(width: kSpace16),
                  _StepNumberBadge(number: widget.step.number),
                  const SizedBox(width: kSpace16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.step.name,
                          style: textTheme.titleMedium?.copyWith(
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: isCompleted
                                ? scheme.onSurfaceVariant
                                : null,
                          ),
                        ),
                        if (shortText.isNotEmpty) ...<Widget>[
                          const SizedBox(height: kSpace4),
                          Text(
                            shortText,
                            maxLines: _isExpanded ? null : 2,
                            overflow: _isExpanded
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                            style: context.scientist.bodySecondary,
                          ),
                        ],
                        AnimatedSize(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          alignment: Alignment.topLeft,
                          child: _isExpanded
                              ? Padding(
                                  padding:
                                      const EdgeInsets.only(top: kSpace12),
                                  child: Text(
                                    widget.step.description,
                                    style: textTheme.bodyMedium,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: kSpace16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        _formatDuration(widget.step.duration),
                        style: context.scientist.numericBody.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: kSpace4),
                      AnimatedRotation(
                        duration: const Duration(milliseconds: 150),
                        turns: _isExpanded ? 0.5 : 0,
                        child: Icon(
                          Icons.expand_more,
                          size: 18,
                          color: context.scientist.onSurfaceFaint,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (isLabScientist) ...<Widget>[
                const SizedBox(height: kSpace12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _isPicking ? null : _pickAttachment,
                    icon: _isPicking
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          )
                        : const Icon(Icons.upload_file_outlined, size: 16),
                    label: Text(_isPicking ? 'Selecting…' : 'Submit material'),
                  ),
                ),
              ],
              if (attachments.isNotEmpty) ...<Widget>[
                const SizedBox(height: kSpace12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (int i = 0; i < attachments.length; i++) ...<Widget>[
                      if (i > 0) const SizedBox(height: kSpace8),
                      ProjectAttachmentRow(
                        attachment: attachments[i],
                        trailingIcon: isLabScientist
                            ? Icons.close_rounded
                            : Icons.download_rounded,
                        trailingTooltip:
                            isLabScientist ? 'Remove' : 'Download',
                        onTrailingPressed: isLabScientist
                            ? () => _removeAttachment(attachments[i])
                            : () => _mockDownload(attachments[i]),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LeadingCompletion extends StatelessWidget {
  const _LeadingCompletion({
    required this.isCompleted,
    required this.isInteractive,
    required this.onTap,
  });

  final bool isCompleted;
  final bool isInteractive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.appColorScheme;
    final Widget circle = Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isCompleted ? scheme.primary : scheme.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: scheme.primary,
          width: 1.5,
        ),
      ),
      child: isCompleted
          ? Icon(
              Icons.check_rounded,
              size: 14,
              color: scheme.onPrimary,
            )
          : const SizedBox.shrink(),
    );
    if (!isInteractive) {
      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: circle,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Tooltip(
        message: isCompleted ? 'Mark as not completed' : 'Mark as completed',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: circle,
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
