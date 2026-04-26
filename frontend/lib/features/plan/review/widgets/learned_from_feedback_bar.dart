import 'package:flutter/material.dart';

import '../../../../core/app_constants.dart';

/// Shown at the bottom of the plan review when the backend used prior
/// few-shot corrections in this generation.
class LearnedFromFeedbackBar extends StatelessWidget {
  const LearnedFromFeedbackBar({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Agent learned from your feedback',
      child: Material(
        color: scheme.tertiaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(kRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: kSpace16,
            vertical: kSpace12,
          ),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 22,
                color: scheme.onTertiaryContainer,
              ),
              const SizedBox(width: kSpace12),
              Expanded(
                child: Text(
                  'Agent learned from your feedback',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onTertiaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
