import 'package:flutter/material.dart' hide Material, Step;

import '../../../models/experiment_plan.dart';

class StepTile extends StatelessWidget {
  const StepTile({
    super.key,
    required this.step,
  });

  final Step step;

  String _formatDuration(Duration value) {
    if (value.inDays > 0 && value.inHours % 24 == 0) {
      return '${value.inDays} days';
    }
    if (value.inDays > 0) {
      return '${value.inDays} days ${value.inHours.remainder(24)} hours';
    }
    return '${value.inHours} hours';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: Text('${step.number}. ${step.name}'),
        subtitle: Text(_formatDuration(step.duration)),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(step.description),
          ),
        ],
      ),
    );
  }
}
