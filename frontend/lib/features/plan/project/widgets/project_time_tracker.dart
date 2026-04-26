import 'package:flutter/material.dart' hide Material, Step;

import '../../../../core/app_constants.dart';
import '../../../../core/theme/theme_context.dart';
import '../../../../models/project.dart';

/// Compact visual showing elapsed vs. estimated project duration.
///
/// The bar fills proportionally to `elapsed / estimated`. When elapsed
/// exceeds the estimate the bar turns into the "overdue" accent, giving
/// a quick at-a-glance signal that the project is behind schedule.
///
/// Shared by both roles (read-only).
class ProjectTimeTracker extends StatelessWidget {
  const ProjectTimeTracker({
    super.key,
    required this.project,
  });

  final Project project;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = context.appColorScheme;
    final DateTime now = DateTime.now();
    final Duration estimated = project.plan.timePlan.totalDuration;
    final Duration elapsed = now.difference(project.startedAt);
    final Duration remaining = estimated - elapsed;
    final double ratio =
        estimated.inMilliseconds > 0
            ? elapsed.inMilliseconds / estimated.inMilliseconds
            : 0;
    final double clampedRatio = ratio.clamp(0, 1).toDouble();
    final bool isOverdue = remaining.isNegative;
    final bool isNearDeadline = !isOverdue && ratio >= 0.85;
    final Color barColor = isOverdue
        ? _kOverdueColor
        : (isNearDeadline ? _kWarningColor : scheme.primary);
    final Color labelColor = isOverdue
        ? _kOverdueColor
        : (isNearDeadline ? _kWarningColor : scheme.onSurface);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: kSpace24,
        vertical: kSpace16,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                isOverdue
                    ? Icons.warning_amber_rounded
                    : Icons.schedule_rounded,
                size: 18,
                color: labelColor,
              ),
              const SizedBox(width: kSpace8),
              Text(
                isOverdue ? 'OVERDUE' : 'PROJECT TIME',
                style: textTheme.labelSmall?.copyWith(color: labelColor),
              ),
              const Spacer(),
              Text(
                _buildStatusLabel(elapsed, remaining, isOverdue),
                style: textTheme.labelSmall?.copyWith(
                  color: labelColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpace12),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: CustomPaint(
                size: const Size(double.infinity, 6),
                painter: _TimeBarPainter(
                  ratio: clampedRatio,
                  barColor: barColor,
                  trackColor: scheme.outline.withValues(alpha: 0.25),
                  isOverdue: isOverdue,
                ),
              ),
            ),
          ),
          const SizedBox(height: kSpace12),
          Row(
            children: <Widget>[
              _TimeMetric(
                label: 'Elapsed',
                value: _formatDuration(elapsed),
                color: scheme.onSurface,
                textTheme: textTheme,
              ),
              const Spacer(),
              _TimeMetric(
                label: 'Estimated',
                value: _formatDuration(estimated),
                color: scheme.onSurfaceVariant,
                textTheme: textTheme,
                alignment: CrossAxisAlignment.end,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _buildStatusLabel(
    Duration elapsed,
    Duration remaining,
    bool isOverdue,
  ) {
    if (isOverdue) {
      return '${_formatDuration(remaining.abs())} over estimate';
    }
    return '${_formatDuration(remaining)} remaining';
  }

  String _formatDuration(Duration value) {
    final int totalDays = value.inDays.abs();
    final int totalHours = value.inHours.abs();
    if (totalDays >= 7) {
      final int weeks = totalDays ~/ 7;
      final int days = totalDays % 7;
      if (days == 0) {
        return '$weeks${weeks == 1 ? ' week' : ' weeks'}';
      }
      return '${weeks}w ${days}d';
    }
    if (totalDays > 0) {
      final int hours = totalHours % 24;
      if (hours == 0) {
        return '$totalDays${totalDays == 1 ? ' day' : ' days'}';
      }
      return '${totalDays}d ${hours}h';
    }
    return '$totalHours${totalHours == 1 ? ' hour' : ' hours'}';
  }
}

const Color _kOverdueColor = Color(0xFFE57373);
const Color _kWarningColor = Color(0xFFFFB74D);

class _TimeMetric extends StatelessWidget {
  const _TimeMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.textTheme,
    this.alignment = CrossAxisAlignment.start,
  });

  final String label;
  final String value;
  final Color color;
  final TextTheme textTheme;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          value,
          style: context.scientist.numericBody.copyWith(color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: context.appColorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Draws a segmented track bar: a filled portion up to [ratio] in
/// [barColor], the remainder in [trackColor]. When [isOverdue] the
/// filled portion gets subtle animated stripes (via a diagonal hatch)
/// so the "overdue" state pops at a glance even without colour vision.
class _TimeBarPainter extends CustomPainter {
  _TimeBarPainter({
    required this.ratio,
    required this.barColor,
    required this.trackColor,
    required this.isOverdue,
  });

  final double ratio;
  final Color barColor;
  final Color trackColor;
  final bool isOverdue;

  @override
  void paint(Canvas canvas, Size size) {
    final double h = size.height;
    final Paint trackPaint = Paint()..color = trackColor;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, h),
      trackPaint,
    );
    final double filledWidth = size.width * ratio;
    if (filledWidth <= 0) {
      return;
    }
    final Paint barPaint = Paint()..color = barColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, filledWidth, h), barPaint);
    if (isOverdue) {
      final Paint stripePaint = Paint()
        ..color = barColor.withValues(alpha: 0.5)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      const double gap = 6;
      for (double x = -h; x < filledWidth + h; x += gap) {
        canvas.drawLine(
          Offset(x, h),
          Offset(x + h, 0),
          stripePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TimeBarPainter oldDelegate) {
    return ratio != oldDelegate.ratio ||
        barColor != oldDelegate.barColor ||
        trackColor != oldDelegate.trackColor ||
        isOverdue != oldDelegate.isOverdue;
  }
}
