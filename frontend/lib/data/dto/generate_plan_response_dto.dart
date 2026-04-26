import 'experiment_plan_nested_dto.dart';
import 'grounding_summary_dto.dart';
import 'literature_qc_dto.dart';

class GeneratePlanResponseDto {
  const GeneratePlanResponseDto({
    required this.requestId,
    required this.qc,
    this.planId,
    this.plan,
    this.groundingSummary,
    this.promptVersions,
  });

  factory GeneratePlanResponseDto.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? rawPromptVersions =
        json['prompt_versions'] as Map<String, dynamic>?;
    return GeneratePlanResponseDto(
      planId: json['plan_id'] as String?,
      requestId: json['request_id'] as String? ?? '',
      qc: LiteratureQcDto.fromJson(
        json['qc'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      plan: json['plan'] == null
          ? null
          : BackendExperimentPlanDto.fromJson(
              json['plan'] as Map<String, dynamic>,
            ),
      groundingSummary: json['grounding_summary'] == null
          ? null
          : GroundingSummaryDto.fromJson(
              json['grounding_summary'] as Map<String, dynamic>,
            ),
      promptVersions: rawPromptVersions
          ?.map((String k, dynamic v) => MapEntry(k, v.toString())),
    );
  }

  final String? planId;
  final String requestId;
  final LiteratureQcDto qc;
  final BackendExperimentPlanDto? plan;
  final GroundingSummaryDto? groundingSummary;
  final Map<String, String>? promptVersions;
}
