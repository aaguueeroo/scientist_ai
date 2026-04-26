import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_constants.dart';
import '../../../core/app_routes.dart';
import '../../../core/theme/theme_context.dart';
import '../../../models/literature_qc.dart';
import '../../../ui/app_surface.dart';

/// Shown when experiment-plan returns QC but no structured plan body.
class PlanQcOnlyView extends StatelessWidget {
  const PlanQcOnlyView({
    super.key,
    required this.qc,
    required this.onRetry,
  });

  final LiteratureQcResult qc;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        Text(
          'No experiment plan generated',
          style: textTheme.headlineMedium,
        ),
        const SizedBox(height: kSpace12),
        Text(
          'Marie completed a literature quality check, but did not produce a '
          'full protocol for this query. This often happens when the novelty '
          'gate flags very close prior work.',
          style: context.scientist.bodySecondary,
        ),
        const SizedBox(height: kSpace24),
        AppSurface(
          padding: const EdgeInsets.all(kSpace16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Novelty: ${qc.novelty}', style: textTheme.titleSmall),
              const SizedBox(height: kSpace8),
              if (qc.confidence.isNotEmpty)
                Text(
                  'Confidence: ${qc.confidence}',
                  style: context.scientist.bodySecondary,
                ),
              if (qc.tier0Drops > 0) ...<Widget>[
                const SizedBox(height: kSpace4),
                Text(
                  'Tier-0 drops: ${qc.tier0Drops}',
                  style: context.scientist.bodySecondary,
                ),
              ],
            ],
          ),
        ),
        if (qc.similaritySuggestion != null) ...<Widget>[
          const SizedBox(height: kSpace16),
          AppSurface(
            padding: const EdgeInsets.all(kSpace16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Similar work suggestion',
                  style: textTheme.titleSmall,
                ),
                const SizedBox(height: kSpace8),
                Text(
                  qc.similaritySuggestion!.title,
                  style: textTheme.bodyMedium,
                ),
                if ((qc.similaritySuggestion!.whyRelevant ?? '')
                    .isNotEmpty) ...<Widget>[
                  const SizedBox(height: kSpace8),
                  Text(
                    qc.similaritySuggestion!.whyRelevant!,
                    style: context.scientist.bodySecondary,
                  ),
                ],
              ],
            ),
          ),
        ],
        if (qc.references.isNotEmpty) ...<Widget>[
          const SizedBox(height: kSpace16),
          Text('QC references', style: textTheme.titleSmall),
          const SizedBox(height: kSpace8),
          ...qc.references.map(
            (QcReference r) => Padding(
              padding: const EdgeInsets.only(bottom: kSpace8),
              child: AppSurface(
                padding: const EdgeInsets.all(kSpace12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(r.title, style: textTheme.bodyMedium),
                    if ((r.whyRelevant ?? '').isNotEmpty)
                      Text(
                        r.whyRelevant!,
                        style: context.scientist.bodySecondary,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: kSpace32),
        Row(
          children: <Widget>[
            FilledButton(
              onPressed: () => context.go(kRouteLiterature),
              child: const Text('Back to literature'),
            ),
            const SizedBox(width: kSpace12),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ],
    );
  }
}
