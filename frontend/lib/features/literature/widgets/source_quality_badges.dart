import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_constants.dart';

/// Compact arc-gauge showing trust score (0–1) as a percentage.
class SourceScoreBadge extends StatelessWidget {
  const SourceScoreBadge({super.key, required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final int percent = (score * 100).round();
    final Color scoreColor = _colorForScore(score);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: 18,
          height: 18,
          child: CustomPaint(
            painter: _ArcGaugePainter(
              progress: score,
              color: scoreColor,
              trackColor: scoreColor.withValues(alpha: 0.18),
            ),
          ),
        ),
        const SizedBox(width: kSpace4),
        Text(
          '$percent%',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: scoreColor,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  static Color _colorForScore(double score) {
    if (score >= 0.75) return AppColors.feedbackPositive;
    if (score >= 0.50) return AppColors.accent;
    if (score >= 0.25) return const Color(0xFFD4A843);
    return const Color(0xFFD06060);
  }
}

/// Trust tier from the backend (e.g. tier_1_peer_reviewed).
class SourceTierChip extends StatelessWidget {
  const SourceTierChip({super.key, required this.tier});

  final String tier;

  static String labelForTier(String tier) {
    final String t = tier.toLowerCase();
    if (t.contains('tier_1')) {
      return 'Peer-reviewed';
    }
    if (t.contains('tier_2')) {
      return 'Preprint / gray lit';
    }
    if (t.contains('tier_3')) {
      return 'General web';
    }
    return tier.replaceAll('_', ' ');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.skeleton.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: AppColors.skeleton.withValues(alpha: 0.4),
          width: 0.75,
        ),
      ),
      child: Text(
        labelForTier(tier),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Pill badge indicating whether a source is officially verified.
class SourceVerifiedBadge extends StatelessWidget {
  const SourceVerifiedBadge({super.key, required this.isVerified});

  final bool isVerified;

  static const Color _verifiedColor = AppColors.feedbackPositive;
  static const Color _unverifiedColor = Color(0xFFD4A843);

  @override
  Widget build(BuildContext context) {
    final Color color = isVerified ? _verifiedColor : _unverifiedColor;
    final IconData icon = isVerified
        ? Icons.verified_outlined
        : Icons.warning_amber_rounded;
    final String label = isVerified ? 'Verified' : 'Unverified';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: 0.75,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArcGaugePainter extends CustomPainter {
  const _ArcGaugePainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (math.min(size.width, size.height) - 2.5) / 2;
    const double strokeWidth = 2.0;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    if (progress <= 0) return;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ArcGaugePainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor;
}
