import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_constants.dart';
import '../../../core/theme/theme_context.dart';
import '../../plan/review/models/change_target.dart';
import '../../plan/review/models/feedback_polarity.dart';
import '../../plan/review/models/review_section.dart';
import '../../plan/review/plan_review_controller.dart';
import 'focus_target_registry.dart';

enum _FlashAccentKind {
  target,
  like,
  dislike,
}

/// Wraps a focusable region of the read-only review body (a section, a
/// step, a material) so the Reviewer screen can programmatically locate
/// it. In the Reviewer, fills the region with a short translucent tint that
/// fades out (no border), aligned with [ColorScheme] accents used elsewhere
/// in plan review.
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

class _FocusHighlightContainerState extends State<FocusHighlightContainer>
    with SingleTickerProviderStateMixin {
  final GlobalKey _key = GlobalKey();
  late AnimationController _flashController;
  late Animation<double> _flashOpacity;
  _FlashAccentKind? _flashKind;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _flashOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _flashController,
        curve: Curves.easeOutCubic,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startFlashIfFocused();
    });
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  void _startFlashIfFocused() {
    if (!mounted) {
      return;
    }
    if (FocusTargetRegistry.maybeOf(context) == null) {
      return;
    }
    final PlanReviewController c = context.read<PlanReviewController>();
    final _FlashAccentKind? kind = _resolveFlashKind(c);
    if (kind == null) {
      return;
    }
    setState(() {
      _flashKind = kind;
    });
    _flashController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final FocusTargetRegistry? registry = FocusTargetRegistry.maybeOf(context);
    if (registry != null) {
      _registerSelf(registry);
    }
    final Widget body = KeyedSubtree(key: _key, child: widget.child);
    if (registry == null) {
      return body;
    }
    if (_flashKind == null) {
      return body;
    }
    final _FlashAccentKind kind = _flashKind!;
    return AnimatedBuilder(
      animation: _flashController,
      builder: (BuildContext context, Widget? child) {
        final double opacity = _flashOpacity.value;
        if (opacity < 0.01) {
          return child!;
        }
        final ColorScheme scheme = context.appColorScheme;
        final Color accent = switch (kind) {
          _FlashAccentKind.target => scheme.primary,
          _FlashAccentKind.like => scheme.tertiary,
          _FlashAccentKind.dislike => scheme.error,
        };
        final double blendT = switch (kind) {
          _FlashAccentKind.target => 0.22,
          _FlashAccentKind.like => 0.18,
          _FlashAccentKind.dislike => 0.16,
        } *
            opacity;
        final Color fill = Color.lerp(
              scheme.surface,
              accent,
              blendT.clamp(0.0, 1.0),
            ) ??
            accent;
        return Container(
          padding: const EdgeInsets.all(kSpace8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kRadius),
            color: fill,
          ),
          child: child,
        );
      },
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

  _FlashAccentKind? _resolveFlashKind(PlanReviewController controller) {
    if (widget.target != null) {
      if (controller.focusedTarget == widget.target) {
        return _FlashAccentKind.target;
      }
      return null;
    }
    if (widget.section != null) {
      if (controller.focusedSection == widget.section &&
          controller.focusedPolarity != null) {
        return controller.focusedPolarity == FeedbackPolarity.like
            ? _FlashAccentKind.like
            : _FlashAccentKind.dislike;
      }
    }
    return null;
  }
}
