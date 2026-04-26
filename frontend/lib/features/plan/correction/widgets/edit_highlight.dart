import 'package:flutter/material.dart';

import '../../../../core/app_constants.dart';
import '../../../../core/theme/theme_context.dart';

/// Visual tokens shared by every edit-mode highlight in the correction
/// flow. They are tuned to read on top of the project's muted dark surface
/// (`AppColors.surface` 0xFF222628) without competing with the accent.
class EditHighlightTokens {
  const EditHighlightTokens._();

  /// Warm amber used for "this field was edited during the current
  /// session". Matches the first batch color so changes feel consistent
  /// across edit and review modes.
  static const Color editedAccent = Color(0xFFE6B56B);

  /// Lime accent used for "this container was added during the current
  /// session". Distinct from [editedAccent] so insertions read as new.
  static const Color insertedAccent = Color(0xFFB7D86A);

  static const double tintAlpha = 0.12;
  static const double cornerRadius = kRadius;
  /// In-field highlight while the user is typing in the inline editor.
  static const double activeEditTextBackgroundAlpha = 0.2;
}

/// Whether an edit-mode container is unchanged, edited, or freshly added.
enum EditChangeKind {
  unchanged,
  edited,
  inserted,
}

/// Returns [base] with the "edited value" treatment applied when
/// [isChanged] is `true`: warm amber color + bold weight. When
/// [isChanged] is `false`, returns [base] unchanged.
TextStyle? editedTextStyle(TextStyle? base, {required bool isChanged}) {
  if (!isChanged) {
    return base;
  }
  final TextStyle resolved = base ?? const TextStyle();
  return resolved.copyWith(
    color: EditHighlightTokens.editedAccent,
    fontWeight: FontWeight.w700,
  );
}

/// Soft background for text while the inline field is in edit mode. Distinct
/// from the committed [editedTextStyle] (amber) treatment.
TextStyle? editingTextHighlight(TextStyle? base) {
  final TextStyle resolved = base ?? const TextStyle();
  return resolved.copyWith(
    backgroundColor: EditHighlightTokens.editedAccent.withValues(
      alpha: EditHighlightTokens.activeEditTextBackgroundAlpha,
    ),
  );
}

/// Wraps an editable container (step / material tile) with a colored
/// outline + soft tint when [kind] is not [EditChangeKind.unchanged].
/// Adds a small "Edited" / "Added" badge in the top-left corner so the
/// status is legible at a glance.
class EditedContainerHighlight extends StatelessWidget {
  const EditedContainerHighlight({
    super.key,
    required this.kind,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.borderRadius,
    this.showBadge = true,
  });

  final EditChangeKind kind;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    if (kind == EditChangeKind.unchanged) {
      return Padding(padding: padding, child: child);
    }
    final Color accent = colorForKind(kind);
    final BorderRadius radius = borderRadius ??
        BorderRadius.circular(EditHighlightTokens.cornerRadius);
    return Padding(
      padding: padding,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: EditHighlightTokens.tintAlpha),
              borderRadius: radius,
            ),
            child: child,
          ),
          if (showBadge)
            PositionedDirectional(
              top: -10,
              start: kSpace12,
              child: _EditChangeBadge(kind: kind),
            ),
        ],
      ),
    );
  }

  static Color colorForKind(EditChangeKind kind) {
    switch (kind) {
      case EditChangeKind.unchanged:
        return Colors.transparent;
      case EditChangeKind.edited:
        return EditHighlightTokens.editedAccent;
      case EditChangeKind.inserted:
        return EditHighlightTokens.insertedAccent;
    }
  }
}

class _EditChangeBadge extends StatelessWidget {
  const _EditChangeBadge({required this.kind});

  final EditChangeKind kind;

  @override
  Widget build(BuildContext context) {
    final Color accent = EditedContainerHighlight.colorForKind(kind);
    final String label = kind == EditChangeKind.inserted ? 'Added' : 'Edited';
    final IconData icon = kind == EditChangeKind.inserted
        ? Icons.add_rounded
        : Icons.edit_rounded;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: kSpace8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 11, color: accent),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

/// Slim red row rendered in place of a removed step or material while the
/// user is editing the draft. Hovering reveals the full removed content,
/// tapping toggles an inline expansion so the user never loses context.
class RemovedDraftSlot extends StatefulWidget {
  const RemovedDraftSlot({
    super.key,
    required this.title,
    required this.removedLabel,
    this.detail,
    this.padding = const EdgeInsets.symmetric(
      horizontal: kSpace12,
      vertical: kSpace8,
    ),
  });

  final String title;
  final String removedLabel;
  final String? detail;
  final EdgeInsetsGeometry padding;

  @override
  State<RemovedDraftSlot> createState() => _RemovedDraftSlotState();
}

class _RemovedDraftSlotState extends State<RemovedDraftSlot> {
  bool _isHovered = false;
  bool _isExpanded = false;

  void _setHovered(bool value) {
    if (_isHovered == value) return;
    setState(() => _isHovered = value);
  }

  void _toggleExpanded() {
    setState(() => _isExpanded = !_isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.appColorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color accent = scheme.error;
    final String? detailText = widget.detail;
    final bool hasDetail = detailText != null && detailText.isNotEmpty;
    return Tooltip(
      message: hasDetail
          ? '${widget.removedLabel} removed: ${widget.title}\n$detailText'
          : '${widget.removedLabel} removed: ${widget.title}',
      waitDuration: const Duration(milliseconds: 250),
      preferBelow: false,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleExpanded,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: widget.padding,
            decoration: BoxDecoration(
              color: _isHovered || _isExpanded
                  ? accent.withValues(alpha: 0.2)
                  : accent.withValues(alpha: 0.12),
              borderRadius:
                  BorderRadius.circular(EditHighlightTokens.cornerRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: kSpace8),
                    Icon(
                      Icons.delete_outline_rounded,
                      size: 14,
                      color: accent,
                    ),
                    const SizedBox(width: kSpace8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: <InlineSpan>[
                            TextSpan(
                              text: '${widget.removedLabel} removed',
                              style: textTheme.labelMedium?.copyWith(
                                color: accent,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            TextSpan(
                              text: '  •  ${widget.title}',
                              style: textTheme.labelMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                                fontStyle: FontStyle.italic,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: scheme.onSurfaceVariant
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: kSpace8),
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: accent.withValues(alpha: 0.85),
                    ),
                  ],
                ),
                if (_isExpanded && hasDetail) ...<Widget>[
                  const SizedBox(height: kSpace8),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 22),
                    child: Text(
                      detailText,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        decoration: TextDecoration.lineThrough,
                        decorationColor:
                            scheme.onSurfaceVariant.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
