import 'package:flutter/material.dart' hide Material;
import 'package:flutter/material.dart' as m show Material;

import '../../../../core/app_constants.dart';
import '../../../../core/theme/theme_context.dart';
import '../models/plan_comment.dart';
import '../review_color_palette.dart';

/// Floating card with a comment editor. Shown via [Overlay] anchored next
/// to the user's selection or the existing comment marker.
class CommentPopover extends StatefulWidget {
  const CommentPopover({
    super.key,
    required this.initialBody,
    required this.onSave,
    this.onCancel,
    this.onDelete,
    this.authorLabel,
    this.title,
    this.quote,
  });

  final String initialBody;
  final ValueChanged<String> onSave;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;
  final String? authorLabel;
  final String? title;
  final String? quote;

  @override
  State<CommentPopover> createState() => _CommentPopoverState();
}

class _CommentPopoverState extends State<CommentPopover> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialBody);
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSave() {
    final String value = _controller.text.trim();
    if (value.isEmpty) return;
    widget.onSave(value);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.appColorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.92, end: 1.0),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutBack,
      builder: (BuildContext context, double scale, Widget? child) {
        return Transform.scale(
          scale: scale,
          alignment: Alignment.topLeft,
          child: child,
        );
      },
      child: m.Material(
        elevation: 8,
        color: scheme.surface,
        borderRadius: BorderRadius.circular(kRadius),
        clipBehavior: Clip.antiAlias,
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(kSpace12),
          decoration: BoxDecoration(
            border: Border.all(
              color: kCommentMarkerColor.withValues(alpha: 0.4),
            ),
            borderRadius: BorderRadius.circular(kRadius),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.chat_bubble_outline_rounded,
                      size: 16, color: kCommentMarkerColor),
                  const SizedBox(width: kSpace8),
                  Text(
                    widget.title ?? 'Comment',
                    style: textTheme.labelMedium,
                  ),
                  const Spacer(),
                  if (widget.authorLabel != null)
                    Text(
                      widget.authorLabel!,
                      style: textTheme.labelSmall?.copyWith(
                        color: context.scientist.onSurfaceFaint,
                      ),
                    ),
                ],
              ),
              if (widget.quote != null) ...<Widget>[
                const SizedBox(height: kSpace8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: kSpace8,
                    vertical: kSpace4,
                  ),
                  decoration: BoxDecoration(
                    color: kCommentMarkerColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(kRadius - 4),
                    border: Border(
                      left: BorderSide(
                        color: kCommentMarkerColor.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    '"${widget.quote!}"',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: context.scientist.onSurfaceFaint,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: kSpace12),
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                minLines: 2,
                maxLines: 5,
                style: textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Write a comment...',
                  hintStyle: textTheme.bodyMedium?.copyWith(
                    color: context.scientist.onSurfaceFaint,
                  ),
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(kRadius - 2),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: kSpace12),
              Row(
                children: <Widget>[
                  if (widget.onDelete != null)
                    IconButton(
                      tooltip: 'Delete comment',
                      onPressed: widget.onDelete,
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: scheme.error,
                      ),
                    ),
                  const Spacer(),
                  if (widget.onCancel != null)
                    TextButton(
                      onPressed: widget.onCancel,
                      child: const Text('Cancel'),
                    ),
                  const SizedBox(width: kSpace8),
                  FilledButton(
                    onPressed: _handleSave,
                    child: const Text('Save'),
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

/// Read-only popover that shows an existing comment's body with optional
/// edit / delete affordances.
class CommentReadPopover extends StatelessWidget {
  const CommentReadPopover({
    super.key,
    required this.comment,
    required this.authorLabel,
    this.onEdit,
    this.onDelete,
  });

  final PlanComment comment;
  final String authorLabel;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.appColorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return m.Material(
      elevation: 8,
      color: scheme.surface,
      borderRadius: BorderRadius.circular(kRadius),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(kSpace12),
        decoration: BoxDecoration(
          border: Border.all(
            color: kCommentMarkerColor.withValues(alpha: 0.4),
          ),
          borderRadius: BorderRadius.circular(kRadius),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.chat_bubble_outline_rounded,
                    size: 16, color: kCommentMarkerColor),
                const SizedBox(width: kSpace8),
                Text(authorLabel, style: textTheme.labelMedium),
                const Spacer(),
                Text(
                  '"${comment.anchor.quote}"',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    color: context.scientist.onSurfaceFaint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: kSpace8),
            Text(comment.body, style: textTheme.bodyMedium),
            const SizedBox(height: kSpace8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                if (onDelete != null)
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: onDelete,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: scheme.error,
                    ),
                  ),
                if (onEdit != null)
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: const Text('Edit'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
