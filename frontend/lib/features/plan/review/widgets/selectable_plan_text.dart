import 'dart:math' as math;

import 'dart:ui' as ui show BoxHeightStyle, Rect;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Material;
import 'package:flutter/material.dart' as m show Material;
import 'package:provider/provider.dart';

import '../../../../core/app_constants.dart';
import '../models/change_target.dart';
import '../models/plan_comment.dart';
import '../plan_review_controller.dart';
import '../review_color_palette.dart';
import 'comment_popover.dart';
import 'suggestion_text_spans.dart';

/// Places the top-left of the popover so it stays within the safe viewport,
/// shifting left or above the selection when needed.
Offset _clampPopoverToViewport({
  required Offset unclamped,
  required Size popoverSize,
  required ui.Rect? selectionRect,
  required double safeLeft,
  required double safeTop,
  required double safeRight,
  required double safeBottom,
}) {
  double x = unclamped.dx;
  double y = unclamped.dy;
  final double w = popoverSize.width;
  final double h = popoverSize.height;
  if (y + h > safeBottom) {
    if (selectionRect != null) {
      final double aboveY = selectionRect.top - h - 8;
      if (aboveY >= safeTop) {
        y = aboveY;
      } else {
        y = math.max(safeTop, safeBottom - h);
      }
    } else {
      y = math.max(safeTop, safeBottom - h);
    }
  }
  if (y < safeTop) {
    y = safeTop;
  }
  if (x + w > safeRight) {
    x = safeRight - w;
  }
  if (x < safeLeft) {
    x = safeLeft;
  }
  if (x + w > safeRight) {
    x = math.max(safeLeft, safeRight - w);
  }
  return Offset(x, y);
}

/// Text widget that lets users select any portion of plan content and
/// attach a comment via a floating chip. Existing comments anchored to
/// [target] are rendered with a colored underline by
/// [buildSuggestionAwareSpan] and clicking the underlined span re-opens
/// the comment.
class SelectablePlanText extends StatefulWidget {
  const SelectablePlanText({
    super.key,
    required this.target,
    required this.text,
    this.style,
    this.maxLines,
    this.textAlign,
  });

  final ChangeTarget target;
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextAlign? textAlign;

  @override
  State<SelectablePlanText> createState() => _SelectablePlanTextState();
}

class _SelectablePlanTextState extends State<SelectablePlanText> {
  final GlobalKey _textKey = GlobalKey();
  final OverlayPortalController _commentChipController =
      OverlayPortalController();
  final OverlayPortalController _popoverController = OverlayPortalController();
  TextSelection? _selection;
  Offset? _pointerLocal;
  /// Global bounds of the active selection, used to anchor the chip and popover.
  ui.Rect? _selectionRectGlobal;
  Offset? _popoverGlobal;
  PlanComment? _editingComment;
  bool _isCreatingComment = false;
  /// Captured when opening the "new comment" popover. [TapRegion] clears
  /// [SelectableText] selection on any tap outside the text (including the
  /// popover), so we must not rely on [_selection] at save time.
  int? _pendingCreateStart;
  int? _pendingCreateEnd;
  /// When [false], an opened existing comment is shown in read-only
  /// [CommentReadPopover], switching to [true] for [CommentPopover] edit.
  bool _isEditingOpenComment = false;

  @override
  void dispose() {
    if (_commentChipController.isShowing) _commentChipController.hide();
    if (_popoverController.isShowing) _popoverController.hide();
    super.dispose();
  }

  void _handleSelectionChanged(
    TextSelection selection,
    SelectionChangedCause? cause,
  ) {
    final bool hasSelection =
        !selection.isCollapsed && selection.start != selection.end;
    setState(() {
      _selection = hasSelection ? selection : null;
      if (hasSelection) {
        _updateSelectionLayoutFromTextPainter();
      } else {
        _selectionRectGlobal = null;
      }
    });
    if (hasSelection) {
      _showCommentChip();
      if (_selectionRectGlobal == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _selection == null) {
            return;
          }
          setState(_updateSelectionLayoutFromTextPainter);
        });
      }
    } else {
      _hideCommentChip();
    }
  }

  void _showCommentChip() {
    if (!_commentChipController.isShowing) {
      _commentChipController.show();
    }
  }

  void _hideCommentChip() {
    if (_commentChipController.isShowing) {
      _commentChipController.hide();
    }
  }

  void _dismissChip() {
    if (_selection == null && !_commentChipController.isShowing) return;
    setState(() {
      _selection = null;
      _selectionRectGlobal = null;
    });
    _hideCommentChip();
  }

  void _openCreateCommentPopover() {
    final TextSelection? sel = _selection;
    if (sel == null) return;
    final int len = widget.text.length;
    final int s = sel.start.clamp(0, len);
    final int e = sel.end.clamp(0, len);
    final String quote = widget.text.substring(s, e);
    if (quote.isEmpty) return;
    setState(() {
      _editingComment = null;
      _isCreatingComment = true;
      _isEditingOpenComment = false;
      _pendingCreateStart = s;
      _pendingCreateEnd = e;
      _updateSelectionLayoutFromTextPainter();
      _popoverGlobal = _resolvePopoverUnclampedAnchor();
    });
    _hideCommentChip();
    if (!_popoverController.isShowing) _popoverController.show();
  }

  void _openExistingCommentPopover(PlanComment comment, Offset globalPos) {
    setState(() {
      _editingComment = comment;
      _isCreatingComment = false;
      _isEditingOpenComment = false;
      _pendingCreateStart = null;
      _pendingCreateEnd = null;
      _popoverGlobal = globalPos;
    });
    if (!_popoverController.isShowing) _popoverController.show();
  }

  void _closePopover() {
    setState(() {
      _editingComment = null;
      _isCreatingComment = false;
      _isEditingOpenComment = false;
      _pendingCreateStart = null;
      _pendingCreateEnd = null;
      _popoverGlobal = null;
    });
    if (_popoverController.isShowing) _popoverController.hide();
  }

  void _openCommentForEdit() {
    setState(() {
      _isEditingOpenComment = true;
    });
  }

  void _returnCommentToViewMode() {
    setState(() {
      _isEditingOpenComment = false;
    });
  }

  String _authorIdForPopover(PlanComment? comment, bool isCreating) {
    if (isCreating) {
      return PlanReviewController.kLocalAuthorId;
    }
    if (comment != null) {
      return comment.authorId;
    }
    return PlanReviewController.kLocalAuthorId;
  }

  void _updateSelectionLayoutFromTextPainter() {
    _selectionRectGlobal = null;
    if (_selection == null || _selection!.isCollapsed) {
      return;
    }
    final RenderBox? textBox =
        _textKey.currentContext?.findRenderObject() as RenderBox?;
    if (textBox == null || !textBox.hasSize) {
      return;
    }
    final TextStyle baseStyle =
        widget.style ?? DefaultTextStyle.of(context).style;
    final int len = widget.text.length;
    final int s0 = _selection!.start.clamp(0, len);
    final int e0 = _selection!.end.clamp(0, len);
    if (s0 >= e0) {
      return;
    }
    final TextSpan span = TextSpan(
      text: widget.text,
      style: baseStyle,
    );
    final TextPainter painter = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: widget.maxLines,
    )..layout(
        maxWidth: textBox.size.width,
        minWidth: 0,
      );
    final List<TextBox> boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: s0, extentOffset: e0),
    );
    if (boxes.isEmpty) {
      return;
    }
    double minL = double.infinity;
    double maxR = 0.0;
    double minT = double.infinity;
    double maxB = 0.0;
    for (final TextBox b in boxes) {
      minL = math.min(minL, b.left);
      maxR = math.max(maxR, b.right);
      minT = math.min(minT, b.top);
      maxB = math.max(maxB, b.bottom);
    }
    final Offset topLeft = textBox.localToGlobal(Offset(minL, minT));
    _selectionRectGlobal = ui.Rect.fromLTRB(
      topLeft.dx,
      topLeft.dy,
      topLeft.dx + (maxR - minL),
      topLeft.dy + (maxB - minT),
    );
  }

  /// Top-left of the popover, directly under the selected text, before
  /// [CommentPopover] viewport fitting.
  Offset? _resolvePopoverUnclampedAnchor() {
    if (_selectionRectGlobal != null) {
      return Offset(
        _selectionRectGlobal!.left,
        _selectionRectGlobal!.bottom + 6,
      );
    }
    return _resolveAnchorPositionFallback();
  }

  /// Used when layout metrics are not ready yet.
  Offset? _resolveAnchorPositionFallback() {
    final RenderBox? box =
        _textKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) {
      return null;
    }
    final Offset origin = box.localToGlobal(Offset.zero);
    if (_pointerLocal != null) {
      return origin + _pointerLocal! + const Offset(0, 12);
    }
    return origin + const Offset(0, 24);
  }

  @override
  Widget build(BuildContext context) {
    final PlanReviewController controller =
        context.watch<PlanReviewController>();
    final TextStyle baseStyle =
        widget.style ?? DefaultTextStyle.of(context).style;
    final TextSpan span = buildSuggestionAwareSpan(
      controller: controller,
      target: widget.target,
      text: widget.text,
      baseStyle: baseStyle,
    );
    final List<PlanComment> commentsHere =
        controller.commentsForTarget(widget.target, widget.text);
    final bool selectableEnabled = controller.mode != ReviewMode.editing &&
        !controller.isHistoricalView &&
        !controller.isReadOnlyFocus;
    return MouseRegion(
      onHover: (PointerHoverEvent event) {
        _pointerLocal = event.localPosition;
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          KeyedSubtree(
            key: _textKey,
            child: selectableEnabled
                ? TapRegion(
                    groupId: this,
                    onTapOutside: (_) {
                      if (_popoverController.isShowing) {
                        return;
                      }
                      _dismissChip();
                    },
                    child: SelectableText.rich(
                      span,
                      maxLines: widget.maxLines,
                      textAlign: widget.textAlign ?? TextAlign.start,
                      onSelectionChanged: _handleSelectionChanged,
                    ),
                  )
                : Text.rich(
                    span,
                    maxLines: widget.maxLines,
                    textAlign: widget.textAlign ?? TextAlign.start,
                  ),
          ),
          if (commentsHere.isNotEmpty)
            Positioned.fill(
              child: _CommentHitOverlay(
                textBoxKey: _textKey,
                target: widget.target,
                text: widget.text,
                comments: commentsHere,
                style: baseStyle,
                onCommentTapped: (PlanComment c, Offset globalPos) =>
                    _openExistingCommentPopover(c, globalPos),
              ),
            ),
          OverlayPortal(
            controller: _commentChipController,
            overlayChildBuilder: (BuildContext ctx) => TapRegion(
              groupId: this,
              child: _CommentChipOverlay(
                positionGlobal: _commentChipOffset(),
                onPressed: _openCreateCommentPopover,
              ),
            ),
          ),
          OverlayPortal(
            controller: _popoverController,
            overlayChildBuilder: (BuildContext ctx) {
              final String authorId = _authorIdForPopover(
                _editingComment,
                _isCreatingComment,
              );
              return _CommentPopoverOverlay(
                anchorGlobal: _popoverGlobal,
                comment: _editingComment,
                isCreating: _isCreatingComment,
                isEditingOpenComment: _isEditingOpenComment,
                quote: _selectedQuote(),
                onSaveCreate: (String body) {
                  final int? start = _pendingCreateStart ?? _selection?.start;
                  final int? end = _pendingCreateEnd ?? _selection?.end;
                  if (start == null || end == null) {
                    _closePopover();
                    return;
                  }
                  final int len = widget.text.length;
                  final int s = start.clamp(0, len);
                  final int e = end.clamp(0, len);
                  if (s >= e) {
                    _closePopover();
                    return;
                  }
                  controller.addComment(
                    target: widget.target,
                    quote: widget.text.substring(s, e),
                    start: s,
                    end: e,
                    body: body,
                  );
                  _closePopover();
                },
                onSaveEdit: (String body) {
                  final PlanComment? c = _editingComment;
                  if (c != null) {
                    controller.updateComment(c.id, body);
                  }
                  _closePopover();
                },
                onDelete: () {
                  final PlanComment? c = _editingComment;
                  if (c != null) {
                    controller.removeComment(c.id);
                  }
                  _closePopover();
                },
                onCancel: _closePopover,
                onEnterEdit: _openCommentForEdit,
                onLeaveEdit: _returnCommentToViewMode,
                authorDisplayName: controller.authorDisplayName(authorId),
                authorImageUrl: controller.authorAvatarUrl(authorId),
                selectionRectGlobal: _selectionRectGlobal,
              );
            },
          ),
        ],
      ),
    );
  }

  /// Global top-left to place the "Comment" chip just under the selection.
  Offset? _commentChipOffset() {
    if (_selectionRectGlobal == null) {
      return null;
    }
    return Offset(
      _selectionRectGlobal!.left,
      _selectionRectGlobal!.bottom + 4,
    );
  }

  String? _selectedQuote() {
    final TextSelection? sel = _selection;
    if (sel == null) return null;
    final int s = sel.start.clamp(0, widget.text.length);
    final int e = sel.end.clamp(0, widget.text.length);
    if (s >= e) return null;
    return widget.text.substring(s, e);
  }
}

class _CommentChipOverlay extends StatelessWidget {
  const _CommentChipOverlay({
    required this.positionGlobal,
    required this.onPressed,
  });

  /// Top-left in global coordinates, usually just below the selected text.
  final Offset? positionGlobal;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (positionGlobal == null) {
      return const SizedBox.shrink();
    }
    final Offset pos = positionGlobal!;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Stack(
      children: <Widget>[
        Positioned(
          left: pos.dx,
          top: pos.dy,
          child: m.Material(
            color: Colors.transparent,
            child: Tooltip(
              message: 'Add comment',
              child: InkWell(
                borderRadius: BorderRadius.circular(kRadius),
                onTap: onPressed,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: kSpace8,
                    vertical: kSpace4,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(kRadius),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.add_comment_outlined,
                        size: 14,
                        color: kCommentMarkerColor,
                      ),
                      const SizedBox(width: kSpace4),
                      Text(
                        'Comment',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: kCommentMarkerColor),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CommentPopoverOverlay extends StatelessWidget {
  const _CommentPopoverOverlay({
    required this.anchorGlobal,
    required this.comment,
    required this.isCreating,
    required this.isEditingOpenComment,
    required this.quote,
    required this.onSaveCreate,
    required this.onSaveEdit,
    required this.onDelete,
    required this.onCancel,
    required this.onEnterEdit,
    required this.onLeaveEdit,
    required this.authorDisplayName,
    required this.authorImageUrl,
    this.selectionRectGlobal,
  });

  final Offset? anchorGlobal;
  final PlanComment? comment;
  final bool isCreating;
  final bool isEditingOpenComment;
  final String? quote;
  final ValueChanged<String> onSaveCreate;
  final ValueChanged<String> onSaveEdit;
  final VoidCallback onDelete;
  final VoidCallback onCancel;
  final VoidCallback onEnterEdit;
  final VoidCallback onLeaveEdit;
  final String authorDisplayName;
  final String authorImageUrl;
  final ui.Rect? selectionRectGlobal;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final double safeLeft = kSpace16 + mq.padding.left;
    final double safeTop = kSpace16 + mq.padding.top;
    final double safeRight = mq.size.width - kSpace16 - mq.padding.right;
    final double safeBottom = mq.size.height - kSpace16 - mq.padding.bottom;
    final Size estSize;
    if (isCreating) {
      estSize = const Size(300, 340);
    } else if (comment != null && !isEditingOpenComment) {
      estSize = const Size(320, 300);
    } else {
      estSize = const Size(300, 340);
    }
    final Offset unclamped = anchorGlobal ?? Offset(safeLeft, safeTop);
    final Offset pos = _clampPopoverToViewport(
      unclamped: unclamped,
      popoverSize: estSize,
      selectionRect: selectionRectGlobal,
      safeLeft: safeLeft,
      safeTop: safeTop,
      safeRight: safeRight,
      safeBottom: safeBottom,
    );
    final double left = pos.dx;
    final double top = pos.dy;
    final Widget popoverChild;
    if (isCreating) {
      popoverChild = CommentPopover(
        initialBody: '',
        quote: quote,
        authorLabel: authorDisplayName,
        title: 'New comment',
        onSave: onSaveCreate,
        onCancel: onCancel,
        onDelete: null,
      );
    } else if (comment != null && !isEditingOpenComment) {
      popoverChild = CommentReadPopover(
        comment: comment!,
        authorName: authorDisplayName,
        authorImageUrl: authorImageUrl,
        onEdit: onEnterEdit,
        onDelete: onDelete,
      );
    } else {
      final PlanComment c = comment!;
      popoverChild = CommentPopover(
        initialBody: c.body,
        quote: c.anchor.quote,
        authorLabel: authorDisplayName,
        title: 'Edit comment',
        onSave: onSaveEdit,
        onCancel: onLeaveEdit,
        onDelete: onDelete,
      );
    }
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onCancel,
          ),
        ),
        Positioned(
          left: left,
          top: top,
          child: popoverChild,
        ),
      ],
    );
  }
}

/// Invisible overlay that captures taps on commented text spans and
/// surfaces them as a click on the corresponding comment marker.
class _CommentHitOverlay extends StatelessWidget {
  const _CommentHitOverlay({
    required this.textBoxKey,
    required this.target,
    required this.text,
    required this.comments,
    required this.style,
    required this.onCommentTapped,
  });

  final GlobalKey textBoxKey;
  final ChangeTarget target;
  final String text;
  final List<PlanComment> comments;
  final TextStyle style;
  final void Function(PlanComment, Offset) onCommentTapped;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Stack(
          children: <Widget>[
            for (final PlanComment c in comments)
              ..._buildHitRects(c, constraints),
          ],
        );
      },
    );
  }

  List<Widget> _buildHitRects(
    PlanComment comment,
    BoxConstraints constraints,
  ) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1000,
    )..layout(maxWidth: constraints.maxWidth);
    final int start = comment.anchor.start.clamp(0, text.length);
    final int end = comment.anchor.end.clamp(0, text.length);
    if (start >= end) return <Widget>[];
    final List<TextBox> boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: end),
      boxHeightStyle: ui.BoxHeightStyle.includeLineSpacingMiddle,
    );
    return <Widget>[
      for (final TextBox tb in boxes)
        Positioned(
          left: tb.left,
          top: tb.top,
          width: tb.right - tb.left,
          height: tb.bottom - tb.top,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                final RenderBox? textBox = textBoxKey.currentContext
                    ?.findRenderObject() as RenderBox?;
                final Offset global = (textBox != null)
                    ? textBox.localToGlobal(Offset(tb.left, tb.bottom + 4))
                    : Offset.zero;
                onCommentTapped(comment, global);
              },
            ),
          ),
        ),
    ];
  }
}
