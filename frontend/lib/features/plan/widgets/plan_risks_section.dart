import 'package:flutter/material.dart';

import '../../../core/app_constants.dart';
import '../../../core/theme/theme_context.dart';
import '../../../models/experiment_plan.dart';
import '../../../ui/app_section_header.dart';
import '../../../ui/app_surface.dart';

/// Displays the list of risks at the bottom of any plan view.
class PlanRisksSection extends StatelessWidget {
  const PlanRisksSection({
    super.key,
    required this.risks,
  });

  final List<PlanRisk> risks;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const AppSectionHeader(title: 'Risks'),
        if (risks.isEmpty)
          Text(
            'No risks listed.',
            style: context.scientist.bodySecondary,
          )
        else
          Column(
            children: <Widget>[
              for (int i = 0; i < risks.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(height: kSpace12),
                _RiskTile(risk: risks[i]),
              ],
            ],
          ),
      ],
    );
  }
}

class _RiskTile extends StatelessWidget {
  const _RiskTile({required this.risk});

  final PlanRisk risk;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return AppSurface(
      padding: const EdgeInsets.all(kSpace16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  risk.description,
                  style: textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: kSpace16),
              _LikelihoodChip(likelihood: risk.likelihood),
            ],
          ),
          if (risk.mitigation.isNotEmpty) ...<Widget>[
            const SizedBox(height: kSpace12),
            _LabeledLine(
              label: 'Mitigation',
              value: risk.mitigation,
            ),
          ],
          if (risk.complianceNote != null &&
              risk.complianceNote!.isNotEmpty) ...<Widget>[
            const SizedBox(height: kSpace8),
            _LabeledLine(
              label: 'Compliance note',
              value: risk.complianceNote!,
            ),
          ],
        ],
      ),
    );
  }
}

class _LabeledLine extends StatelessWidget {
  const _LabeledLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: context.scientist.bodySecondary,
        children: <TextSpan>[
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}

class _LikelihoodChip extends StatelessWidget {
  const _LikelihoodChip({required this.likelihood});

  final PlanRiskLikelihood likelihood;

  String get _label {
    switch (likelihood) {
      case PlanRiskLikelihood.low:
        return 'Low';
      case PlanRiskLikelihood.medium:
        return 'Medium';
      case PlanRiskLikelihood.high:
        return 'High';
    }
  }

  Color _backgroundColor(ColorScheme scheme) {
    switch (likelihood) {
      case PlanRiskLikelihood.low:
        return scheme.primaryContainer;
      case PlanRiskLikelihood.medium:
        return scheme.secondaryContainer;
      case PlanRiskLikelihood.high:
        return scheme.errorContainer;
    }
  }

  Color _foregroundColor(ColorScheme scheme) {
    switch (likelihood) {
      case PlanRiskLikelihood.low:
        return scheme.primary;
      case PlanRiskLikelihood.medium:
        return scheme.secondary;
      case PlanRiskLikelihood.high:
        return scheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.appColorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: kSpace8,
        vertical: kSpace4,
      ),
      decoration: BoxDecoration(
        color: _backgroundColor(scheme),
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: Text(
        _label,
        style: textTheme.labelSmall?.copyWith(
          color: _foregroundColor(scheme),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
