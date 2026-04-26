import '../../core/id_generator.dart';
import '../../models/experiment_plan.dart';
import '../../models/generate_plan_result.dart';
import '../../models/literature_qc.dart';
import '../dto/experiment_plan_nested_dto.dart'
    show
        BackendExperimentPlanDto,
        BackendMaterialDto,
        BudgetItemDto,
        ProtocolStepDto,
        TimelineEntryDto;
import '../dto/generate_plan_response_dto.dart';
import '../dto/plan_reference_dto.dart';
import 'experiment_plan_mapper.dart';

/// Maps backend `GeneratePlanResponse` nested plan + QC into domain.
class BackendPlanMapper {
  const BackendPlanMapper._();

  /// Mock milestone labels cycled by protocol step index (product placeholder).
  static const List<String> kMockMilestoneLabels = <String>[
    'Checkpoint review',
    'Lab readiness',
    'Sample intake',
    'Data lock',
    'Sign-off',
    'Handoff',
    'QC gate',
    'Milestone',
    'Review point',
  ];

  static GeneratePlanResult toGeneratePlanResult(GeneratePlanResponseDto dto) {
    final LiteratureQcResult qc = _qcToDomain(dto.qc);
    final GroundingSummary? gs = dto.groundingSummary == null
        ? null
        : GroundingSummary(
            verifiedCount: dto.groundingSummary!.verifiedCount,
            unverifiedCount: dto.groundingSummary!.unverifiedCount,
            tier0Drops: dto.groundingSummary!.tier0Drops,
          );
    final ExperimentPlan? plan =
        dto.plan == null ? null : backendPlanToDomain(dto.plan!);
    return GeneratePlanResult(
      planId: dto.planId,
      requestId: dto.requestId,
      qc: qc,
      plan: plan,
      groundingSummary: gs,
      promptVersions: dto.promptVersions,
      usedPriorFeedback: dto.usedPriorFeedback,
    );
  }

  static LiteratureQcResult _qcToDomain(dynamic qcDto) {
    return LiteratureQcResult(
      novelty: qcDto.novelty as String,
      confidence: qcDto.confidence as String? ?? '',
      references: (qcDto.references as List)
          .map((dynamic e) => _refToDomain(e as PlanReferenceDto))
          .toList(),
      similaritySuggestion: qcDto.similaritySuggestion == null
          ? null
          : _refToDomain(qcDto.similaritySuggestion as PlanReferenceDto),
      tier0Drops: qcDto.tier0Drops as int,
    );
  }

  static QcReference _refToDomain(PlanReferenceDto r) {
    return QcReference(
      title: r.title,
      url: r.url,
      doi: r.doi,
      whyRelevant: r.whyRelevant,
      tier: r.tier,
      verified: r.verified,
      verificationUrl: r.verificationUrl,
      confidence: r.confidence,
      isSimilaritySuggestion: r.isSimilaritySuggestion,
    );
  }

  static ExperimentPlan backendPlanToDomain(BackendExperimentPlanDto be) {
    final List<PlanPhase> phases = be.timeline
        .map(
          (TimelineEntryDto e) => PlanPhase(
            phase: e.phase,
            durationDays: e.durationDays,
            dependsOn: e.dependsOn,
          ),
        )
        .toList();
    final List<Step> protocolSteps = _protocolToSteps(be.protocol, be.timeline);
    final int totalSeconds = phases.fold<int>(
      0,
      (int sum, PlanPhase p) => sum + p.durationDays * Duration.secondsPerDay,
    );
    final TimePlan timePlan = TimePlan(
      totalDuration: Duration(seconds: totalSeconds),
      steps: protocolSteps,
    );
    List<Material> materials = be.materials
        .map((BackendMaterialDto m) => _backendMaterialToDomain(m))
        .toList();
    if (materials.isEmpty && be.budget != null) {
      materials = be.budget!.items
          .map(
            (BudgetItemDto item) => Material(
              id: generateLocalId('mat'),
              title: item.label,
              catalogNumber: '',
              description: '',
              amount: 1,
              price: item.costUsd,
            ),
          )
          .toList();
    }
    final double total = be.budget?.totalUsd ??
        materials.fold<double>(
          0,
          (double s, Material x) =>
              s + (x.unitCostUsd ?? x.price) * (x.qty ?? x.amount),
        );
    final Budget budget = Budget(
      total: total,
      materials: materials,
    );
    final PlanValidation? validation = be.validation == null
        ? null
        : PlanValidation(
            successMetrics: be.validation!.successMetrics,
            failureMetrics: be.validation!.failureMetrics,
            miqeCompliance: be.validation!.miqeCompliance,
          );
    final String hypothesis = be.hypothesis ?? '';
    return ExperimentPlan(
      hypothesis: hypothesis,
      description: hypothesis.isNotEmpty ? '' : '',
      budget: budget,
      timePlan: timePlan,
      timelinePhases: phases,
      validation: validation,
      risks: be.risks.map(ExperimentPlanMapper.planRiskFromDto).toList(),
    );
  }

  static List<Step> _protocolToSteps(
    List<ProtocolStepDto> protocol,
    List<TimelineEntryDto> timeline,
  ) {
    final List<Step> out = <Step>[];
    for (int i = 0; i < protocol.length; i++) {
      final ProtocolStepDto p = protocol[i];
      // Map step duration from timeline by matching index when lengths align;
      // otherwise spread timeline days evenly across protocol steps.
      final int days = _durationDaysForProtocolIndex(i, protocol.length, timeline);
      final String milestone =
          kMockMilestoneLabels[i % kMockMilestoneLabels.length];
      out.add(
        Step(
          id: generateLocalId('step'),
          number: p.order > 0 ? p.order : i + 1,
          duration: Duration(days: days > 0 ? days : 1),
          name: p.technique,
          description: p.description,
          dependsOn: const <String>[],
          milestone: milestone,
        ),
      );
    }
    return out;
  }

  static int _durationDaysForProtocolIndex(
    int index,
    int protocolLen,
    List<TimelineEntryDto> timeline,
  ) {
    if (timeline.isEmpty) {
      return 1;
    }
    if (timeline.length == protocolLen) {
      return timeline[index].durationDays;
    }
    final int totalDays =
        timeline.fold<int>(0, (int s, TimelineEntryDto e) => s + e.durationDays);
    if (protocolLen <= 0) {
      return 1;
    }
    final int base = totalDays ~/ protocolLen;
    final int extra = totalDays % protocolLen;
    return base + (index < extra ? 1 : 0);
  }

  static Material _backendMaterialToDomain(BackendMaterialDto m) {
    final int q = m.qty ?? 1;
    final double unit = m.unitCostUsd ?? 0;
    return Material(
      id: generateLocalId('mat'),
      title: m.reagent,
      catalogNumber: m.sku ?? '',
      description: m.notes ?? '',
      amount: q,
      price: unit,
      reagent: m.reagent,
      vendor: m.vendor,
      sku: m.sku,
      qty: m.qty,
      qtyUnit: m.qtyUnit,
      unitCostUsd: m.unitCostUsd,
      notes: m.notes,
      tier: m.tier,
      verified: m.verified,
      verificationUrl: m.verificationUrl,
      confidence: m.confidence,
    );
  }
}
