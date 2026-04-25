import '../../core/id_generator.dart';
import '../../models/experiment_plan.dart';
import '../dto/budget_dto.dart';
import '../dto/experiment_plan_dto.dart';
import '../dto/material_dto.dart';
import '../dto/step_dto.dart';
import '../dto/time_plan_dto.dart';

class ExperimentPlanMapper {
  const ExperimentPlanMapper._();

  static ExperimentPlan toDomain(ExperimentPlanDto dto) {
    return ExperimentPlan(
      description: dto.description,
      budget: _budgetToDomain(dto.budget),
      timePlan: _timePlanToDomain(dto.timePlan),
    );
  }

  static Budget _budgetToDomain(BudgetDto dto) {
    return Budget(
      total: dto.total,
      materials: dto.materials.map(_materialToDomain).toList(),
    );
  }

  static Material _materialToDomain(MaterialDto dto) {
    return Material(
      id: generateLocalId('mat'),
      title: dto.title,
      catalogNumber: dto.catalogNumber,
      description: dto.description,
      amount: dto.amount,
      price: dto.price,
    );
  }

  static TimePlan _timePlanToDomain(TimePlanDto dto) {
    return TimePlan(
      totalDuration: Duration(seconds: dto.totalDurationSeconds),
      steps: dto.steps.map(_stepToDomain).toList(),
    );
  }

  static Step _stepToDomain(StepDto dto) {
    return Step(
      id: generateLocalId('step'),
      number: dto.number,
      duration: Duration(seconds: dto.durationSeconds),
      name: dto.name,
      description: dto.description,
      milestone: dto.milestone,
    );
  }
}
