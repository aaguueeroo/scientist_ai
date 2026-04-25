import 'package:flutter/material.dart';

import '../../../../core/app_constants.dart';
import '../models/change_target.dart';
import '../models/plan_comment.dart';
import '../plan_review_controller.dart';
import '../review_color_palette.dart';

/// Builds a [TextSpan] that reflects accepted-batch version highlighting
/// (a soft translucent background in the latest-touching batch's color
/// plus an inline caret marker that surfaces the v0 baseline value on
/// hover) and existing comment underlines for the given [target].
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
  GestureRecognizerFactoryProvider? recognizerFactory,
}) {
  final Color? batchColor = controller.colorForTarget(target);
  final bool hasEditFromBaseline =
      batchColor != null && controller.hasFieldEditFromBaseline(target);
  final Color? highlightColor =
      hasEditFromBaseline ? batchColor.withValues(alpha: 0.16) : null;
  final TextSpan baseSpan = _buildBaseSpan(
    text: text,
    style: baseStyle,
    comments: controller.commentsForTarget(target, text),
    backgroundColor: highlightColor,
  );
  if (!hasEditFromBaseline) {
    return baseSpan;
  }
  final String originalLabel = controller.originalLabelFor(target) ?? '';
  final double caretHeight = (baseStyle.fontSize ?? 14) * 0.9;
  return TextSpan(
    children: <InlineSpan>[
      baseSpan,
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: _OriginalValueCaret(
          color: batchColor,
          height: caretHeight,
          originalLabel: originalLabel,
        ),
      ),
    ],
  );
}

TextSpan _buildBaseSpan({
  required String text,
  required TextStyle style,
  required List<PlanComment> comments,
  Color? backgroundColor,
}) {
  final TextStyle effectiveStyle = backgroundColor != null
      ? style.copyWith(background: Paint()..color = backgroundColor)
      : style;
  if (comments.isEmpty) {
    return TextSpan(text: text, style: effectiveStyle);
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
        style: effectiveStyle,
      ));
    }
    children.add(TextSpan(
      text: text.substring(r.start, r.end),
      style: effectiveStyle.copyWith(
        decoration: TextDecoration.underline,
        decorationColor: kCommentMarkerColor,
        decorationStyle: TextDecorationStyle.wavy,
        decorationThickness: 1.6,
      ),
    ));
    cursor = r.end;
  }
  if (cursor < text.length) {
    children.add(TextSpan(text: text.substring(cursor), style: effectiveStyle));
  }
  return TextSpan(children: children, style: effectiveStyle);
}

/// Thin vertical caret rendered just after a highlighted span. Hovering
/// it surfaces a tooltip with the v0 baseline value of that field.
class _OriginalValueCaret extends StatelessWidget {
  const _OriginalValueCaret({
    required this.color,
    required this.height,
    required this.originalLabel,
  });

  final Color color;
  final double height;
  final String originalLabel;

  @override
  Widget build(BuildContext context) {
    final String message = originalLabel.isEmpty
        ? 'Original: (empty)'
        : 'Original: $originalLabel';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kSpace4 / 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.help,
        child: Tooltip(
          message: message,
          waitDuration: const Duration(milliseconds: 100),
          child: Container(
            width: 2,
            height: height,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      ),
    );
  }
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
