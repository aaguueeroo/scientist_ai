import 'package:flutter/material.dart';

import '../../../../core/app_constants.dart';
import '../../../../core/theme/theme_context.dart';
import '../../../../models/project.dart';

/// A single attachment line under a step. Used in both lab scientist
/// (with a remove action) and funder (with a download action) modes.
class ProjectAttachmentRow extends StatelessWidget {
  const ProjectAttachmentRow({
    super.key,
    required this.attachment,
    required this.trailingIcon,
    required this.trailingTooltip,
    required this.onTrailingPressed,
  });

  final ProjectAttachment attachment;
  final IconData trailingIcon;
  final String trailingTooltip;
  final VoidCallback onTrailingPressed;

  String _formatSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    final double kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }
    final double mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.appColorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: kSpace12,
        vertical: kSpace8,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(kRadius - 2),
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.attach_file_rounded,
            size: 16,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: kSpace8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  attachment.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium,
                ),
                Text(
                  _formatSize(attachment.sizeBytes),
                  style: context.scientist.bodyTertiary,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: trailingTooltip,
            icon: Icon(trailingIcon, size: 16),
            onPressed: onTrailingPressed,
            color: scheme.onSurfaceVariant,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
