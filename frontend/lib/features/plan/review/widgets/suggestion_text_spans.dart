import 'package:flutter/material.dart';

import '../models/change_target.dart';
import '../models/plan_change.dart';
import '../models/plan_comment.dart';
import '../plan_review_controller.dart';
import '../review_color_palette.dart';

/// Builds a [TextSpan] that reflects pending-suggestion strikethrough,
/// accepted batch coloring, and comment underlines for the given [target].
///
/// The caller owns the base [text] (the value currently shown to the user)
/// and the [baseStyle]. The returned span is a [TextSpan] wrapping zero or
/// more child spans so the host widget can use either [Text.rich] or
/// [SelectableText.rich] without losing selection continuity.
TextSpan buildSuggestionAwareSpan({
  required PlanReviewController controller,
  required ChangeTarget target,
  required String text,
  required TextStyle baseStyle,
  TextStyle? newSuggestionStyle,
  TextStyle? oldSuggestionStyle,
  GestureRecognizerFactoryProvider? recognizerFactory,
}) {
  final FieldChange? pending = controller.pendingFieldChangeFor(target);
  if (pending != null) {
    return _buildPendingSpan(
      pending: pending,
      controller: controller,
      target: target,
      baseStyle: baseStyle,
      newSuggestionStyle: newSuggestionStyle,
      oldSuggestionStyle: oldSuggestionStyle,
    );
  }
  final Color? acceptedColor = controller.colorForTarget(target);
  final TextStyle effective = acceptedColor != null
      ? baseStyle.copyWith(color: acceptedColor)
      : baseStyle;
  return _buildBaseSpan(
    text: text,
    style: effective,
    comments: controller.commentsForTarget(target, text),
  );
}

TextSpan _buildPendingSpan({
  required FieldChange pending,
  required PlanReviewController controller,
  required ChangeTarget target,
  required TextStyle baseStyle,
  TextStyle? newSuggestionStyle,
  TextStyle? oldSuggestionStyle,
}) {
  final Color batchColor =
      controller.pendingBatch?.color ?? baseStyle.color ?? Colors.white;
  final TextStyle oldStyle = (oldSuggestionStyle ?? baseStyle).copyWith(
    color: kPendingStrikeColor,
    decoration: TextDecoration.lineThrough,
    decorationColor: kPendingStrikeColor,
  );
  final TextStyle newStyle = (newSuggestionStyle ?? baseStyle).copyWith(
    color: batchColor,
    fontWeight: baseStyle.fontWeight,
  );
  final String beforeText = pending.before?.toString() ?? '';
  final String afterText = pending.after?.toString() ?? '';
  if (beforeText.isEmpty && afterText.isNotEmpty) {
    return TextSpan(text: afterText, style: newStyle);
  }
  if (afterText.isEmpty && beforeText.isNotEmpty) {
    return TextSpan(text: beforeText, style: oldStyle);
  }
  return TextSpan(
    children: <InlineSpan>[
      TextSpan(text: beforeText, style: oldStyle),
      const TextSpan(text: '  '),
      TextSpan(text: afterText, style: newStyle),
    ],
  );
}

TextSpan _buildBaseSpan({
  required String text,
  required TextStyle style,
  required List<PlanComment> comments,
}) {
  if (comments.isEmpty) {
    return TextSpan(text: text, style: style);
  }
  final List<_Range> ranges = <_Range>[];
  for (final PlanComment c in comments) {
    final int start = c.anchor.start.clamp(0, text.length);
    final int end = c.anchor.end.clamp(0, text.length);
    if (end > start) {
      ranges.add(_Range(start, end));
    }
  }
  ranges.sort((a, b) => a.start.compareTo(b.start));
  final List<InlineSpan> children = <InlineSpan>[];
  int cursor = 0;
  for (final _Range r in ranges) {
    if (r.start < cursor) continue;
    if (r.start > cursor) {
      children.add(TextSpan(
        text: text.substring(cursor, r.start),
        style: style,
      ));
    }
    children.add(TextSpan(
      text: text.substring(r.start, r.end),
      style: style.copyWith(
        decoration: TextDecoration.underline,
        decorationColor: kCommentMarkerColor,
        decorationStyle: TextDecorationStyle.wavy,
        decorationThickness: 1.6,
      ),
    ));
    cursor = r.end;
  }
  if (cursor < text.length) {
    children.add(TextSpan(text: text.substring(cursor), style: style));
  }
  return TextSpan(children: children, style: style);
}

class _Range {
  const _Range(this.start, this.end);
  final int start;
  final int end;
}

/// Marker type so the helper can be passed gesture recognizers without
/// pulling Flutter material into model files.
typedef GestureRecognizerFactoryProvider = GestureRecognizerFactory Function(
  String key,
);
