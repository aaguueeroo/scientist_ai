import 'package:flutter/material.dart';

import '../../../core/app_constants.dart';
import '../../../core/theme/theme_context.dart';
import '../../../models/experiment_plan.dart';
import '../../../models/literature_review.dart';
import '../../../models/plan_source_ref.dart';
import 'plan_sources_navigator.dart';

/// References section appended at the bottom of the plan body.
///
/// Renders a numbered list of literature sources (matching badge indices)
/// and, when the plan contains at least one previous-learning ref, a
/// light-bulb entry explaining what that means.
///
/// Requires [PlanSourcesNavigator] in the widget tree (injected by
/// [PlanSourcesNavigatorScope]) so that [GlobalKey]s can be attached.
class PlanReferencesPanel extends StatelessWidget {
  const PlanReferencesPanel({
    super.key,
    required this.plan,
  });

  final ExperimentPlan plan;

  @override
  Widget build(BuildContext context) {
    final PlanSourcesNavigator? navigator =
        PlanSourcesNavigator.maybeOf(context);
    final LiteratureReview? review = navigator?.literatureReview;
    final List<Source> literatureSources =
        (review != null && review.sources.isNotEmpty)
            ? review.sources
            : const <Source>[];
    final bool hasPreviousLearning = planHasPreviousLearning(plan);

    if (literatureSources.isEmpty && !hasPreviousLearning) {
      return const SizedBox.shrink();
    }

    if (navigator == null) {
      return _ReferencesColumn(
        literatureSources: literatureSources,
        hasPreviousLearning: hasPreviousLearning,
        literatureKeys: null,
        previousLearningKey: null,
        highlight: null,
      );
    }

    return ValueListenableBuilder<PlanSourceRef?>(
      valueListenable: navigator.highlightedRef,
      builder: (BuildContext context, PlanSourceRef? highlight, _) {
        return _ReferencesColumn(
          literatureSources: literatureSources,
          hasPreviousLearning: hasPreviousLearning,
          literatureKeys: navigator.literatureKeys,
          previousLearningKey: navigator.previousLearningKey,
          highlight: highlight,
        );
      },
    );
  }
}

class _ReferencesColumn extends StatelessWidget {
  const _ReferencesColumn({
    required this.literatureSources,
    required this.hasPreviousLearning,
    required this.literatureKeys,
    required this.previousLearningKey,
    required this.highlight,
  });

  final List<Source> literatureSources;
  final bool hasPreviousLearning;
  final Map<int, GlobalKey>? literatureKeys;
  final GlobalKey? previousLearningKey;
  final PlanSourceRef? highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: kSpace32),
        const _ReferencesHeader(),
        const SizedBox(height: kSpace12),
        for (int i = 0; i < literatureSources.length; i++)
          _LiteratureRefRow(
            index: i + 1,
            source: literatureSources[i],
            rowKey: literatureKeys?[i + 1],
            isHighlighted: highlight == LiteratureSourceRef(
              referenceIndex: i + 1,
            ),
          ),
        if (hasPreviousLearning)
          _PreviousLearningRow(
            rowKey: previousLearningKey,
            isHighlighted: highlight is PreviousLearningSourceRef,
          ),
      ],
    );
  }
}

class _ReferencesHeader extends StatelessWidget {
  const _ReferencesHeader();

  @override
  Widget build(BuildContext context) {
    return Text(
      'References',
      style: Theme.of(context).textTheme.titleSmall,
    );
  }
}

class _LiteratureRefRow extends StatelessWidget {
  const _LiteratureRefRow({
    required this.index,
    required this.source,
    required this.rowKey,
    this.isHighlighted = false,
  });

  final int index;
  final Source source;
  final GlobalKey? rowKey;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = context.appColorScheme;
    return Padding(
      key: rowKey,
      padding: const EdgeInsets.only(bottom: kSpace8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.all(isHighlighted ? kSpace8 : 0),
        decoration: isHighlighted
            ? BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(kRadius),
                border: Border.all(color: scheme.primary, width: 2),
              )
            : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _RefIndexCircle(index: index, scheme: scheme),
            const SizedBox(width: kSpace8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    source.title,
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    source.author,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviousLearningRow extends StatelessWidget {
  const _PreviousLearningRow({
    required this.rowKey,
    this.isHighlighted = false,
  });

  final GlobalKey? rowKey;
  final bool isHighlighted;

  static const String _kExplanation =
      'This information was refined with knowledge from a previous Marie session.';

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = context.appColorScheme;
    return Padding(
      key: rowKey,
      padding: const EdgeInsets.only(bottom: kSpace8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.all(isHighlighted ? kSpace8 : 0),
        decoration: isHighlighted
            ? BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(kRadius),
                border: Border.all(color: scheme.primary, width: 2),
              )
            : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _LightBulbCircle(scheme: scheme),
            const SizedBox(width: kSpace8),
            Expanded(
              child: Text(
                _kExplanation,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RefIndexCircle extends StatelessWidget {
  const _RefIndexCircle({required this.index, required this.scheme});

  final int index;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$index',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
      ),
    );
  }
}

class _LightBulbCircle extends StatelessWidget {
  const _LightBulbCircle({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primary,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.lightbulb_outline_rounded,
        size: 12,
        color: scheme.onPrimary,
      ),
    );
  }
}
