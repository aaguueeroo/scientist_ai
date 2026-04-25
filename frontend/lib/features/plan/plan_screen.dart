import 'package:flutter/material.dart' hide Material, Step;
import 'package:provider/provider.dart';

import '../../controllers/scientist_controller.dart';
import '../../core/app_constants.dart';
import '../../models/experiment_plan.dart';
import 'widgets/material_tile.dart';
import 'widgets/plan_timeline.dart';
import 'widgets/step_tile.dart';
import 'widgets/summary_header.dart';

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  String _formatTotalDuration(Duration value) {
    final int days = value.inDays;
    final int hours = value.inHours.remainder(24);
    if (hours == 0) {
      return '$days days';
    }
    return '$days days $hours hours';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ScientistController>(
      builder: (
        BuildContext context,
        ScientistController controller,
        Widget? child,
      ) {
        final ExperimentPlan? plan = controller.experimentPlan;
        if (controller.isLoadingPlan && plan == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.planError != null) {
          return Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(kSpaceL),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.error_outline),
                    const SizedBox(height: kSpaceS),
                    Text(controller.planError!),
                    const SizedBox(height: kSpaceS),
                    TextButton(
                      onPressed: controller.loadExperimentPlan,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        if (plan == null) {
          return const Center(child: Text('No experiment plan available.'));
        }
        return ListView(
          padding: const EdgeInsets.all(kSpaceL),
          children: <Widget>[
            SummaryHeader(
              totalTimeLabel: _formatTotalDuration(plan.timePlan.totalDuration),
              totalBudgetLabel: '\$${plan.budget.total.toStringAsFixed(2)}',
            ),
            const SizedBox(height: kSpaceL),
            PlanTimeline(steps: plan.timePlan.steps),
            const SizedBox(height: kSpaceL),
            Text('Steps', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: kSpaceM),
            ...plan.timePlan.steps.map((Step step) => StepTile(step: step)),
            const SizedBox(height: kSpaceL),
            Text('Materials', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: kSpaceM),
            ...plan.budget.materials.map(
              (Material material) => MaterialTile(material: material),
            ),
          ],
        );
      },
    );
  }
}
