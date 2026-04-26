import '../../core/id_generator.dart';
import '../../models/experiment_plan.dart';
import '../dto/budget_dto.dart';
import '../dto/experiment_plan_dto.dart';
import '../dto/material_dto.dart';
import '../dto/plan_source_ref_dto.dart';
import '../dto/risk_dto.dart';
import '../dto/step_dto.dart';
import '../dto/time_plan_dto.dart';

class ExperimentPlanMapper {
  const ExperimentPlanMapper._();

  static ExperimentPlan toDomain(ExperimentPlanDto dto) {
    return ExperimentPlan(
      hypothesis: dto.hypothesis,
      description: dto.description,
      budget: _budgetToDomain(dto.budget),
      timePlan: _timePlanToDomain(dto.timePlan),
      timelinePhases: dto.timelinePhases
          .map(
            (TimelinePhaseDto p) => PlanPhase(
              phase: p.phase,
              durationDays: p.durationDays,
              dependsOn: p.dependsOn,
            ),
          )
          .toList(),
      validation: dto.validation == null
          ? null
          : PlanValidation(
              successMetrics: dto.validation!.successMetrics,
              failureMetrics: dto.validation!.failureMetrics,
              miqeCompliance: dto.validation!.miqeCompliance,
            ),
      stepsSectionSourceRefs:
          PlanSourceRefDto.listFromJson(dto.stepsSectionSourceRefs),
      materialsSectionSourceRefs:
          PlanSourceRefDto.listFromJson(dto.materialsSectionSourceRefs),
      risks: dto.risks.map(planRiskFromDto).toList(),
    );
  }

  static PlanRisk planRiskFromDto(RiskDto dto) => _riskToDomain(dto);

  /// Inverse of [toDomain]. Preserves stable step/material ids so that
  /// snapshots round-trip via JSON (used when embedding a plan inside a
  /// `Review`).
  static ExperimentPlanDto fromDomain(
    ExperimentPlan plan, {
    String currency = 'USD',
  }) {
    return ExperimentPlanDto(
      hypothesis: plan.hypothesis,
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
      timelinePhases: plan.timelinePhases
          .map(
            (PlanPhase p) => TimelinePhaseDto(
              phase: p.phase,
              durationDays: p.durationDays,
              dependsOn: p.dependsOn,
            ),
          )
          .toList(),
      validation: plan.validation == null
          ? null
          : PlanValidationSnapshotDto(
              successMetrics: plan.validation!.successMetrics,
              failureMetrics: plan.validation!.failureMetrics,
              miqeCompliance: plan.validation!.miqeCompliance,
            ),
      stepsSectionSourceRefs:
          PlanSourceRefDto.listToJson(plan.stepsSectionSourceRefs),
      materialsSectionSourceRefs:
          PlanSourceRefDto.listToJson(plan.materialsSectionSourceRefs),
      risks: plan.risks.map(_riskFromDomain).toList(),
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
      sourceRefs: PlanSourceRefDto.listFromJson(dto.sourceRefs),
      reagent: dto.reagent,
      vendor: dto.vendor,
      sku: dto.sku,
      qty: dto.qty,
      qtyUnit: dto.qtyUnit,
      unitCostUsd: dto.unitCostUsd,
      notes: dto.notes,
      tier: dto.tier,
      verified: dto.verified,
      verificationUrl: dto.verificationUrl,
      confidence: dto.confidence,
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
      sourceRefs: PlanSourceRefDto.listToJson(material.sourceRefs),
      reagent: material.reagent,
      vendor: material.vendor,
      sku: material.sku,
      qty: material.qty,
      qtyUnit: material.qtyUnit,
      unitCostUsd: material.unitCostUsd,
      notes: material.notes,
      tier: material.tier,
      verified: material.verified,
      verificationUrl: material.verificationUrl,
      confidence: material.confidence,
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
      sourceRefs: PlanSourceRefDto.listFromJson(dto.sourceRefs),
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
      sourceRefs: PlanSourceRefDto.listToJson(step.sourceRefs),
    );
  }

  static PlanRisk _riskToDomain(RiskDto dto) {
    return PlanRisk(
      id: generateLocalId('risk'),
      description: dto.description,
      likelihood: _likelihoodToDomain(dto.likelihood),
      mitigation: dto.mitigation,
      complianceNote: dto.complianceNote,
    );
  }

  static RiskDto _riskFromDomain(PlanRisk risk) {
    return RiskDto(
      description: risk.description,
      likelihood: risk.likelihood.name,
      mitigation: risk.mitigation,
      complianceNote: risk.complianceNote,
    );
  }

  static PlanRiskLikelihood _likelihoodToDomain(String raw) {
    switch (raw) {
      case 'low':
        return PlanRiskLikelihood.low;
      case 'high':
        return PlanRiskLikelihood.high;
      case 'medium':
      default:
        return PlanRiskLikelihood.medium;
    }
  }
}
