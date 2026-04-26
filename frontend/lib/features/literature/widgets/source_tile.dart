import 'package:flutter/material.dart';

import '../../../core/app_constants.dart';
import '../../../core/theme/theme_context.dart';
import '../../../models/literature_review.dart';
import '../../../ui/app_surface.dart';
import 'source_quality_badges.dart';

class SourceTile extends StatelessWidget {
  const SourceTile({
    super.key,
    required this.source,
  });

  final Source source;

  static const List<String> _months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _formatDate(DateTime value) {
    return '${_months[value.month - 1]} ${value.year}';
  }

  bool get _startsWithUnverifiedPrefix {
    return source.abstractText.startsWith('[Unverified');
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = context.appColorScheme;
    final bool similarity = source.unverifiedSimilaritySuggestion;
    final Widget body = AppSurface(
      padding: const EdgeInsets.all(kSpace16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(kRadius - 2),
            ),
            child: Icon(
              Icons.description_outlined,
              size: 16,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: kSpace16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (similarity) ...<Widget>[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(kSpace8),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(kRadius - 4),
                      border: Border.all(
                        color: scheme.error.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Text(
                      'Similar content only — not HTTP-verified. Treat as a '
                      'starting point, not a confirmed reference.',
                      style: textTheme.labelMedium?.copyWith(
                        color: scheme.onErrorContainer,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: kSpace12),
                ],
                Text(source.title, style: textTheme.titleMedium),
                const SizedBox(height: kSpace4),
                Text(
                  '${source.author}  ·  ${_formatDate(source.dateOfPublication)}',
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: kSpace12),
                Text(
                  source.abstractText,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: context.scientist.bodySecondary.copyWith(
                    fontWeight: _startsWithUnverifiedPrefix
                        ? FontWeight.w500
                        : null,
                  ),
                ),
                const SizedBox(height: kSpace8),
                Text(
                  source.doi,
                  style: context.scientist.bodyTertiaryMonospace
                      .copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: kSpace12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (source.tier != null && source.tier!.isNotEmpty) ...<Widget>[
                SourceTierChip(tier: source.tier!),
                const SizedBox(height: kSpace8),
              ],
              if (!similarity)
                SourceVerifiedBadge(isVerified: source.isVerified),
              if (!similarity) const SizedBox(height: kSpace8),
              SourceScoreBadge(score: source.score),
            ],
          ),
        ],
      ),
    );

    if (!similarity) {
      return body;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.9),
          width: 1.5,
        ),
      ),
      child: body,
    );
  }
}
