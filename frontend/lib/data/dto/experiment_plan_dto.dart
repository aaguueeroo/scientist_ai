import 'budget_dto.dart';
import 'risk_dto.dart';
import 'time_plan_dto.dart';

class ExperimentPlanDto {
  const ExperimentPlanDto({
    required this.description,
    required this.budget,
    required this.timePlan,
    this.stepsSectionSourceRefs = const <Map<String, dynamic>>[],
    this.materialsSectionSourceRefs = const <Map<String, dynamic>>[],
    this.risks = const <RiskDto>[],
  });

  factory ExperimentPlanDto.fromJson(Map<String, dynamic> json) {
    return ExperimentPlanDto(
      description: json['description'] as String,
      budget: BudgetDto.fromJson(json['budget'] as Map<String, dynamic>),
      timePlan:
          TimePlanDto.fromJson(json['time_plan'] as Map<String, dynamic>),
      stepsSectionSourceRefs:
          (json['steps_section_source_refs'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          const <Map<String, dynamic>>[],
      materialsSectionSourceRefs:
          (json['materials_section_source_refs'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          const <Map<String, dynamic>>[],
      risks: (json['risks'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>()
              .map(RiskDto.fromJson)
              .toList() ??
          const <RiskDto>[],
    );
  }

  final String description;
  final BudgetDto budget;
  final TimePlanDto timePlan;

  /// Source references for the Steps section as a whole. Omitted by old clients.
  final List<Map<String, dynamic>> stepsSectionSourceRefs;

  /// Source references for the Materials section as a whole. Omitted by old clients.
  final List<Map<String, dynamic>> materialsSectionSourceRefs;

  /// Risks associated with this plan. Omitted by old clients.
  final List<RiskDto> risks;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'description': description,
      'budget': budget.toJson(),
      'time_plan': timePlan.toJson(),
      if (stepsSectionSourceRefs.isNotEmpty)
        'steps_section_source_refs': stepsSectionSourceRefs,
      if (materialsSectionSourceRefs.isNotEmpty)
        'materials_section_source_refs': materialsSectionSourceRefs,
      if (risks.isNotEmpty) 'risks': risks.map((RiskDto r) => r.toJson()).toList(),
    };
  }
}
