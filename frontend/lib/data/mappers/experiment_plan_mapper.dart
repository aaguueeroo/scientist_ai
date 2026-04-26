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

  /// Inverse of [toDomain]. Preserves stable step/material ids so that
  /// snapshots round-trip via JSON (used when embedding a plan inside a
  /// `Review`).
  static ExperimentPlanDto fromDomain(
    ExperimentPlan plan, {
    String currency = 'USD',
  }) {
    return ExperimentPlanDto(
      description: plan.description,
      budget: BudgetDto(
        total: plan.budget.total,
        currency: currency,
        materials: plan.budget.materials.map(_materialFromDomain).toList(),
      ),
      timePlan: TimePlanDto(
        totalDurationSeconds: plan.timePlan.totalDuration.inSeconds,
        steps: plan.timePlan.steps.map(_stepFromDomain).toList(),
      ),
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
      id: dto.id ?? generateLocalId('mat'),
      title: dto.title,
      catalogNumber: dto.catalogNumber,
      description: dto.description,
      amount: dto.amount,
      price: dto.price,
    );
  }

  static MaterialDto _materialFromDomain(Material material) {
    return MaterialDto(
      id: material.id,
      title: material.title,
      catalogNumber: material.catalogNumber,
      description: material.description,
      amount: material.amount,
      price: material.price,
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
      id: dto.id ?? generateLocalId('step'),
      number: dto.number,
      duration: Duration(seconds: dto.durationSeconds),
      name: dto.name,
      description: dto.description,
      milestone: dto.milestone,
    );
  }

  static StepDto _stepFromDomain(Step step) {
    return StepDto(
      id: step.id,
      number: step.number,
      durationSeconds: step.duration.inSeconds,
      name: step.name,
      description: step.description,
      milestone: step.milestone,
    );
  }
}
