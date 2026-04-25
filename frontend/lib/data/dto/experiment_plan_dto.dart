import 'budget_dto.dart';
import 'time_plan_dto.dart';

class ExperimentPlanDto {
  const ExperimentPlanDto({
    required this.description,
    required this.budget,
    required this.timePlan,
  });

  factory ExperimentPlanDto.fromJson(Map<String, dynamic> json) {
    return ExperimentPlanDto(
      description: json['description'] as String,
      budget: BudgetDto.fromJson(json['budget'] as Map<String, dynamic>),
      timePlan:
          TimePlanDto.fromJson(json['time_plan'] as Map<String, dynamic>),
    );
  }

  final String description;
  final BudgetDto budget;
  final TimePlanDto timePlan;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'description': description,
      'budget': budget.toJson(),
      'time_plan': timePlan.toJson(),
    };
  }
}
