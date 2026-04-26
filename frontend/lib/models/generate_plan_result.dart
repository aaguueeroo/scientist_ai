import 'experiment_plan.dart';
import 'literature_qc.dart';

/// Successful parse of `POST /experiment-plan` (GeneratePlanResponse).
class GeneratePlanResult {
  const GeneratePlanResult({
    required this.requestId,
    required this.qc,
    this.planId,
    this.plan,
    this.groundingSummary,
    this.promptVersions,
    this.usedPriorFeedback = false,
  });

  final String? planId;
  final String requestId;
  final LiteratureQcResult qc;
  final ExperimentPlan? plan;
  final GroundingSummary? groundingSummary;
  final Map<String, String>? promptVersions;

  /// True when the agent incorporated prior user corrections (few-shots).
  final bool usedPriorFeedback;
}
