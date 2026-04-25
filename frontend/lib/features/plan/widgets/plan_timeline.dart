import 'package:flutter/material.dart' hide Material, Step;

import '../../../core/app_constants.dart';
import '../../../models/experiment_plan.dart';

class PlanTimeline extends StatelessWidget {
  const PlanTimeline({
    super.key,
    required this.steps,
  });

  final List<Step> steps;

  String _formatDuration(Duration value) {
    if (value.inDays > 0) {
      if (value.inHours % 24 == 0) {
        return '${value.inDays} d';
      }
      final int hours = value.inHours.remainder(24);
      return '${value.inDays} d $hours h';
    }
    return '${value.inHours} h';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(kSpaceM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Timeline', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: kSpaceM),
            ...List<Widget>.generate(steps.length, (int index) {
              final Step currentStep = steps[index];
              final bool showConnector = index != steps.length - 1;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 24,
                    child: Column(
                      children: <Widget>[
                        const Icon(Icons.circle, size: 12),
                        if (showConnector)
                          Container(
                            width: 2,
                            height: 38,
                            color: Theme.of(context).dividerColor,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: kSpaceM),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: kSpaceS),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Expanded(child: Text(currentStep.name)),
                          const SizedBox(width: kSpaceS),
                          Text(
                            _formatDuration(currentStep.duration),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}
