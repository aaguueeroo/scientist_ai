import 'package:flutter/material.dart';

import '../core/app_constants.dart';
import '../core/theme/theme_context.dart';
import '../features/plan/widgets/plan_sources_navigator.dart';
import '../models/plan_source_ref.dart';

/// Renders a compact row of circular source badges for [refs].
///
/// - Literature refs show a 1-based number inside the circle.
/// - Previous-learning refs show a light-bulb icon inside the circle.
///
/// Tapping a badge scrolls the references panel into view via
/// [PlanSourcesNavigator] (when available in the widget tree).
/// If the navigator is absent (e.g. project flow) taps are no-ops.
class PlanSourceBadges extends StatelessWidget {
  const PlanSourceBadges({
    super.key,
    required this.refs,
  });

  final List<PlanSourceRef> refs;

  @override
  Widget build(BuildContext context) {
    if (refs.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: kSpace4,
      runSpacing: kSpace4,
      children: refs
          .map((PlanSourceRef ref) => _SourceBadge(ref: ref))
          .toList(growable: false),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.ref});

  final PlanSourceRef ref;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.appColorScheme;
    final PlanSourcesNavigator? navigator =
        PlanSourcesNavigator.maybeOf(context);
    return switch (ref) {
      LiteratureSourceRef(referenceIndex: final int idx) =>
        _buildBadge(
          context: context,
          scheme: scheme,
          tooltip: 'Reference $idx',
          onTap: navigator != null
              ? () => navigator.scrollToRef(ref, context)
              : null,
          child: Text(
            '$idx',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
          ),
        ),
      PreviousLearningSourceRef() =>
        _buildBadge(
          context: context,
          scheme: scheme,
          tooltip: 'Previous learning',
          onTap: navigator != null
              ? () => navigator.scrollToRef(ref, context)
              : null,
          isPreviousLearning: true,
          child: Icon(
            Icons.lightbulb_outline_rounded,
            size: 12,
            color: scheme.onPrimary,
          ),
        ),
    };
  }

  Widget _buildBadge({
    required BuildContext context,
    required ColorScheme scheme,
    required String tooltip,
    required VoidCallback? onTap,
    required Widget child,
    bool isPreviousLearning = false,
  }) {
    final Color background = isPreviousLearning
        ? scheme.primary
        : scheme.primaryContainer;
    final Widget badge = Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: onTap != null
              ? SystemMouseCursors.click
              : MouseCursor.defer,
          child: Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
            ),
            child: child,
          ),
        ),
      ),
    );
    return badge;
  }
}
