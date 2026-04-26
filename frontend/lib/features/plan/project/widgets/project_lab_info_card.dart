import 'package:flutter/material.dart';

import '../../../../core/app_constants.dart';
import '../../../../core/theme/theme_context.dart';
import '../../../../models/project.dart';
import '../../../../ui/app_surface.dart';
import '../../../shell/widgets/user_avatar.dart';

/// Funder-only header card with the metadata about who is running the
/// project: lab name, assigned scientist, start and last update dates.
class ProjectLabInfoCard extends StatelessWidget {
  const ProjectLabInfoCard({
    super.key,
    required this.project,
  });

  final Project project;

  String _formatDate(DateTime value) {
    const List<String> months = <String>[
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
    final int monthIndex = value.month - 1;
    final String monthLabel =
        monthIndex >= 0 && monthIndex < months.length ? months[monthIndex] : '?';
    return '$monthLabel ${value.day}, ${value.year}';
  }

  String _formatRelativeDate(DateTime value) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime dateOnly = DateTime(value.year, value.month, value.day);
    final int daysDiff = today.difference(dateOnly).inDays;
    if (daysDiff == 0) {
      return 'Today';
    }
    if (daysDiff == 1) {
      return 'Yesterday';
    }
    if (daysDiff < 7) {
      return '$daysDiff days ago';
    }
    if (daysDiff < 14) {
      return 'Last week';
    }
    final int weeks = daysDiff ~/ 7;
    if (daysDiff < 30) {
      return '$weeks weeks ago';
    }
    final int months = daysDiff ~/ 30;
    if (months == 1) {
      return 'Last month';
    }
    return '$months months ago';
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = context.appColorScheme;
    return AppSurface(
      padding: const EdgeInsets.all(kSpace16),
      child: Row(
        children: <Widget>[
          UserAvatar(
            name: project.assignedScientistName,
            imageUrl: project.assignedScientistAvatarUrl,
            size: 56,
          ),
          const SizedBox(width: kSpace16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('LAB', style: textTheme.labelSmall),
                const SizedBox(height: 2),
                Text(project.labName, style: textTheme.titleMedium),
                const SizedBox(height: kSpace4),
                Text(
                  'Assigned to ${project.assignedScientistName}',
                  style: context.scientist.bodySecondary,
                ),
              ],
            ),
          ),
          const SizedBox(width: kSpace24),
          _LabInfoStat(
            label: 'STARTED',
            value: _formatDate(project.startedAt),
            scheme: scheme,
            textTheme: textTheme,
          ),
          const SizedBox(width: kSpace24),
          _LabInfoStat(
            label: 'LAST UPDATE',
            value: _formatRelativeDate(project.lastUpdatedAt),
            scheme: scheme,
            textTheme: textTheme,
          ),
        ],
      ),
    );
  }
}

class _LabInfoStat extends StatelessWidget {
  const _LabInfoStat({
    required this.label,
    required this.value,
    required this.scheme,
    required this.textTheme,
  });

  final String label;
  final String value;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label, style: textTheme.labelSmall),
        const SizedBox(height: 2),
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }
}
