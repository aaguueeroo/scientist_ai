import 'package:flutter/material.dart';

import '../../../../core/app_constants.dart';

/// Shown when the API returned 200 but could not auto-verify any citation
/// or catalog line ([grounding_caveat] on the plan response).
class GroundingCaveatBar extends StatelessWidget {
  const GroundingCaveatBar({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: message,
      child: Material(
        color: scheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(kRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: kSpace16,
            vertical: kSpace12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.warning_amber_rounded,
                size: 22,
                color: scheme.onErrorContainer,
              ),
              const SizedBox(width: kSpace12),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onErrorContainer,
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
