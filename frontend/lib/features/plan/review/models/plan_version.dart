import '../../../../models/experiment_plan.dart';

class PlanVersion {
  const PlanVersion({
    required this.id,
    required this.snapshot,
    required this.batchId,
    required this.authorId,
    required this.at,
    required this.changeCount,
  });

  final String id;
  final ExperimentPlan snapshot;
  final String? batchId;
  final String authorId;
  final DateTime at;
  final int changeCount;

  bool get isOriginal => batchId == null;
}
