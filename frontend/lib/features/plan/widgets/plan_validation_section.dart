import 'package:flutter/material.dart';

import '../../../core/app_constants.dart';
import '../../../core/theme/theme_context.dart';
import '../../../models/experiment_plan.dart';
import '../../../ui/app_section_header.dart';
import '../../../ui/app_surface.dart';

class PlanValidationSection extends StatelessWidget {
  const PlanValidationSection({
    super.key,
    required this.validation,
  });

  final PlanValidation validation;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool hasContent = validation.successMetrics.isNotEmpty ||
        validation.failureMetrics.isNotEmpty ||
        (validation.miqeCompliance != null &&
            validation.miqeCompliance!.isNotEmpty);
    if (!hasContent) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const AppSectionHeader(title: 'Validation'),
        const SizedBox(height: kSpace12),
        AppSurface(
          padding: const EdgeInsets.all(kSpace16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (validation.successMetrics.isNotEmpty) ...<Widget>[
                Text(
                  'Success metrics',
                  style: textTheme.titleSmall,
                ),
                const SizedBox(height: kSpace8),
                ...validation.successMetrics.map(
                  (String line) => Padding(
                    padding: const EdgeInsets.only(bottom: kSpace4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('• ', style: context.scientist.bodySecondary),
                        Expanded(
                          child: Text(
                            line,
                            style: context.scientist.bodySecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: kSpace16),
              ],
              if (validation.failureMetrics.isNotEmpty) ...<Widget>[
                Text(
                  'Failure metrics',
                  style: textTheme.titleSmall,
                ),
                const SizedBox(height: kSpace8),
                ...validation.failureMetrics.map(
                  (String line) => Padding(
                    padding: const EdgeInsets.only(bottom: kSpace4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('• ', style: context.scientist.bodySecondary),
                        Expanded(
                          child: Text(
                            line,
                            style: context.scientist.bodySecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: kSpace16),
              ],
              if (validation.miqeCompliance != null &&
                  validation.miqeCompliance!.isNotEmpty) ...<Widget>[
                Text(
                  'MIQE compliance',
                  style: textTheme.titleSmall,
                ),
                const SizedBox(height: kSpace8),
                Text(
                  validation.miqeCompliance!,
                  style: context.scientist.bodySecondary,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
