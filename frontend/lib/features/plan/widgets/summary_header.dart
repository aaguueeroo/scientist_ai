import 'package:flutter/material.dart' hide Material, Step;

import '../../../core/app_constants.dart';

class SummaryHeader extends StatelessWidget {
  const SummaryHeader({
    super.key,
    required this.totalTimeLabel,
    required this.totalBudgetLabel,
  });

  final String totalTimeLabel;
  final String totalBudgetLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _SummaryCard(
            icon: Icons.schedule,
            label: 'Total Time',
            value: totalTimeLabel,
          ),
        ),
        const SizedBox(width: kSpaceM),
        Expanded(
          child: _SummaryCard(
            icon: Icons.payments_outlined,
            label: 'Total Budget',
            value: totalBudgetLabel,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(kSpaceM),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 28),
            const SizedBox(width: kSpaceM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: kSpaceXs),
                  Text(value, style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
