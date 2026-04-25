import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_constants.dart';
import '../../plan/review/models/change_target.dart';
import '../../plan/review/models/feedback_polarity.dart';
import '../../plan/review/models/review_section.dart';
import '../../plan/review/plan_review_controller.dart';
import 'focus_target_registry.dart';

const Color _kFocusLikeColor = Color(0xFF66BB6A);
const Color _kFocusDislikeColor = Color(0xFFEF5350);

/// Wraps a focusable region of the read-only review body (a section, a
/// step, a material) so the Reviewer screen can programmatically locate
/// it and tint its border to mirror the focused review's polarity.
///
/// This widget is intentionally a no-op when no [FocusTargetRegistry] is
/// in scope (i.e. on the normal plan review surface): no scroll target is
/// registered and no highlight is drawn.
class FocusHighlightContainer extends StatefulWidget {
  const FocusHighlightContainer({
    super.key,
    required this.child,
    this.section,
    this.target,
  })  : assert(
          (section != null) ^ (target != null),
          'Provide exactly one of section or target.',
        );

  /// Section identifier when this container wraps a major review section
  /// (steps, materials, timeline, ...). Mutually exclusive with [target].
  final ReviewSection? section;

  /// Target identifier when this container wraps a single step or
  /// material. Mutually exclusive with [section].
  final ChangeTarget? target;

  final Widget child;

  @override
  State<FocusHighlightContainer> createState() =>
      _FocusHighlightContainerState();
}

class _FocusHighlightContainerState extends State<FocusHighlightContainer> {
  final GlobalKey _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final FocusTargetRegistry? registry = FocusTargetRegistry.maybeOf(context);
    if (registry != null) {
      _registerSelf(registry);
    }
    final PlanReviewController controller =
        context.watch<PlanReviewController>();
    final Color? borderColor = _resolveBorderColor(controller);
    final Widget body = KeyedSubtree(key: _key, child: widget.child);
    if (borderColor == null) {
      return body;
    }
    return Container(
      padding: const EdgeInsets.all(kSpace8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: borderColor, width: 2),
        color: borderColor.withValues(alpha: 0.06),
      ),
      child: body,
    );
  }

  void _registerSelf(FocusTargetRegistry registry) {
    final ReviewSection? section = widget.section;
    final ChangeTarget? target = widget.target;
    if (section != null) {
      registry.registerSection(section, _key);
    } else if (target != null) {
      registry.registerTarget(target, _key);
    }
  }

  Color? _resolveBorderColor(PlanReviewController controller) {
    final FeedbackPolarity? polarity = controller.focusedPolarity;
    if (polarity == null) return null;
    final ReviewSection? focusedSection = controller.focusedSection;
    final ReviewSection? mySection = widget.section;
    if (focusedSection == null ||
        mySection == null ||
        focusedSection != mySection) {
      return null;
    }
    return _polarityColor(polarity);
  }

  Color _polarityColor(FeedbackPolarity polarity) {
    switch (polarity) {
      case FeedbackPolarity.like:
        return _kFocusLikeColor;
      case FeedbackPolarity.dislike:
        return _kFocusDislikeColor;
    }
  }
}
