import 'budget_dto.dart';
import 'risk_dto.dart';
import 'step_dto.dart';
import 'time_plan_dto.dart';

class TimelinePhaseDto {
  const TimelinePhaseDto({
    required this.phase,
    required this.durationDays,
    this.dependsOn = const <String>[],
  });

  factory TimelinePhaseDto.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw =
        json['depends_on'] as List<dynamic>? ?? <dynamic>[];
    return TimelinePhaseDto(
      phase: json['phase'] as String? ?? '',
      durationDays: (json['duration_days'] as num?)?.toInt() ?? 0,
      dependsOn: raw.map((dynamic e) => e as String).toList(),
    );
  }

  final String phase;
  final int durationDays;
  final List<String> dependsOn;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'phase': phase,
      'duration_days': durationDays,
      'depends_on': dependsOn,
    };
  }
}

class PlanValidationSnapshotDto {
  const PlanValidationSnapshotDto({
    this.successMetrics = const <String>[],
    this.failureMetrics = const <String>[],
    this.miqeCompliance,
  });

  factory PlanValidationSnapshotDto.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawS =
        json['success_metrics'] as List<dynamic>? ?? <dynamic>[];
    final List<dynamic> rawF =
        json['failure_metrics'] as List<dynamic>? ?? <dynamic>[];
    return PlanValidationSnapshotDto(
      successMetrics: rawS.map((dynamic e) => e as String).toList(),
      failureMetrics: rawF.map((dynamic e) => e as String).toList(),
      miqeCompliance: json['miqe_compliance'] as String?,
    );
  }

  final List<String> successMetrics;
  final List<String> failureMetrics;
  final String? miqeCompliance;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'success_metrics': successMetrics,
      'failure_metrics': failureMetrics,
      if (miqeCompliance != null) 'miqe_compliance': miqeCompliance,
    };
  }
}

class ExperimentPlanDto {
  const ExperimentPlanDto({
    this.hypothesis = '',
    required this.description,
    required this.budget,
    required this.timePlan,
    this.timelinePhases = const <TimelinePhaseDto>[],
    this.validation,
    this.stepsSectionSourceRefs = const <Map<String, dynamic>>[],
    this.materialsSectionSourceRefs = const <Map<String, dynamic>>[],
    this.risks = const <RiskDto>[],
  });

  factory ExperimentPlanDto.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? rawTp =
        json['time_plan'] as Map<String, dynamic>?;
    final TimePlanDto timePlan = rawTp == null
        ? const TimePlanDto(totalDurationSeconds: 0, steps: <StepDto>[])
        : TimePlanDto.fromJson(rawTp);
    final List<dynamic>? rawPhases =
        json['timeline_phases'] as List<dynamic>?;
    return ExperimentPlanDto(
      hypothesis: json['hypothesis'] as String? ?? '',
      description: json['description'] as String? ?? '',
      budget: BudgetDto.fromJson(json['budget'] as Map<String, dynamic>),
      timePlan: timePlan,
      timelinePhases: rawPhases == null
          ? const <TimelinePhaseDto>[]
          : rawPhases
              .map(
                (dynamic e) => TimelinePhaseDto.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList(),
      validation: json['validation'] == null
          ? null
          : PlanValidationSnapshotDto.fromJson(
              json['validation'] as Map<String, dynamic>,
            ),
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

  final String hypothesis;
  final String description;
  final BudgetDto budget;
  final TimePlanDto timePlan;
  final List<TimelinePhaseDto> timelinePhases;
  final PlanValidationSnapshotDto? validation;

  /// Source references for the Steps section as a whole. Omitted by old clients.
  final List<Map<String, dynamic>> stepsSectionSourceRefs;

  /// Source references for the Materials section as a whole. Omitted by old clients.
  final List<Map<String, dynamic>> materialsSectionSourceRefs;

  /// Risks associated with this plan. Omitted by old clients.
  final List<RiskDto> risks;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (hypothesis.isNotEmpty) 'hypothesis': hypothesis,
      'description': description,
      'budget': budget.toJson(),
      'time_plan': timePlan.toJson(),
      if (timelinePhases.isNotEmpty)
        'timeline_phases':
            timelinePhases.map((TimelinePhaseDto p) => p.toJson()).toList(),
      if (validation != null) 'validation': validation!.toJson(),
      if (stepsSectionSourceRefs.isNotEmpty)
        'steps_section_source_refs': stepsSectionSourceRefs,
      if (materialsSectionSourceRefs.isNotEmpty)
        'materials_section_source_refs': materialsSectionSourceRefs,
      if (risks.isNotEmpty) 'risks': risks.map((RiskDto r) => r.toJson()).toList(),
    };
  }
}
