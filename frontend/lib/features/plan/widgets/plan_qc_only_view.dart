import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_constants.dart';
import '../../../core/app_routes.dart';
import '../../../core/theme/theme_context.dart';
import '../../../models/literature_qc.dart';
import '../../../ui/app_surface.dart';
import '../../literature/widgets/reference_link.dart';

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
    final ColorScheme scheme = context.appColorScheme;
    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        Semantics(
          label:
              'Warning: literature originality check blocked the experiment plan.',
          container: true,
          child: AppSurface(
            color: AppColors.qcAlertSurface,
            borderColor: AppColors.qcWarning.withValues(alpha: 0.45),
            padding: const EdgeInsets.all(kSpace16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.warning_amber_rounded,
                  size: kPlanQcAlertIconSize,
                  color: AppColors.qcWarning,
                  semanticLabel: 'Warning',
                ),
                const SizedBox(width: kSpace16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Originality concern — no experiment plan',
                        style: textTheme.titleLarge?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: kSpace8),
                      Text(
                        'Marie\'s literature check suggests your request lines up '
                        'very closely with existing publications. When overlap is '
                        'that strong, we treat it like a plagiarism-risk situation: '
                        'Marie stops short of a full protocol so we do not echo or '
                        'repackage prior work.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: kSpace12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(
                            Icons.lightbulb_outline,
                            size: kPlanQcInlineIconSize,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: kSpace8),
                          Expanded(
                            child: Text(
                              'Try narrowing what is genuinely new in your study, '
                              'or review the references below and rewrite your query '
                              'so the contribution is explicit.',
                              style: context.scientist.bodySecondary.copyWith(
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: kSpace24),
        Row(
          children: <Widget>[
            Icon(
              Icons.fact_check_outlined,
              size: kPlanQcInlineIconSize,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: kSpace8),
            Text(
              'Check details',
              style: textTheme.titleSmall,
            ),
          ],
        ),
        const SizedBox(height: kSpace12),
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
                ReferenceTitleLink(
                  title: qc.similaritySuggestion!.title,
                  pageUrl: qc.similaritySuggestion!.url,
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
                    ReferenceTitleLink(
                      title: r.title,
                      pageUrl: r.url,
                      style: textTheme.bodyMedium,
                    ),
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
