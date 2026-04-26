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

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = context.appColorScheme;
    return AppSurface(
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
                  style: context.scientist.bodySecondary,
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
              SourceVerifiedBadge(isVerified: source.isVerified),
              const SizedBox(height: kSpace8),
              SourceScoreBadge(score: source.score),
            ],
          ),
        ],
      ),
    );
  }
}
