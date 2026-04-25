import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/change_target.dart';
import '../plan_review_controller.dart';
import 'suggestion_text_spans.dart';

/// Read-only [Text.rich] that automatically renders pending and accepted
/// suggestion styling for [target]. Use [SelectablePlanText] when the
/// user must be able to select the text to attach a comment.
class SuggestionAwareText extends StatelessWidget {
  const SuggestionAwareText({
    super.key,
    required this.target,
    required this.text,
    this.style,
    this.maxLines,
    this.textAlign,
    this.overflow,
    this.softWrap,
  });

  final ChangeTarget target;
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final bool? softWrap;

  @override
  Widget build(BuildContext context) {
    final PlanReviewController controller =
        context.watch<PlanReviewController>();
    final TextStyle baseStyle =
        style ?? DefaultTextStyle.of(context).style;
    return Text.rich(
      buildSuggestionAwareSpan(
        controller: controller,
        target: target,
        text: text,
        baseStyle: baseStyle,
      ),
      maxLines: maxLines,
      textAlign: textAlign,
      overflow: overflow,
      softWrap: softWrap,
    );
  }
}
