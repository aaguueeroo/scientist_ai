import '../core/id_generator.dart';
import 'plan_source_ref.dart';

enum PlanRiskLikelihood { low, medium, high }

class PlanPhase {
  const PlanPhase({
    required this.phase,
    required this.durationDays,
    this.dependsOn = const <String>[],
  });

  final String phase;
  final int durationDays;
  final List<String> dependsOn;
}

class PlanValidation {
  const PlanValidation({
    required this.successMetrics,
    required this.failureMetrics,
    this.miqeCompliance,
  });

  final List<String> successMetrics;
  final List<String> failureMetrics;
  final String? miqeCompliance;
}

class PlanRisk {
  const PlanRisk({
    required this.id,
    required this.description,
    required this.likelihood,
    required this.mitigation,
    this.complianceNote,
  });

  final String id;
  final String description;
  final PlanRiskLikelihood likelihood;
  final String mitigation;
  final String? complianceNote;

  PlanRisk copyWith({
    String? id,
    String? description,
    PlanRiskLikelihood? likelihood,
    String? mitigation,
    String? complianceNote,
    bool clearComplianceNote = false,
  }) {
    return PlanRisk(
      id: id ?? this.id,
      description: description ?? this.description,
      likelihood: likelihood ?? this.likelihood,
      mitigation: mitigation ?? this.mitigation,
      complianceNote:
          clearComplianceNote ? null : (complianceNote ?? this.complianceNote),
    );
  }
}

class ExperimentPlan {
  const ExperimentPlan({
    this.hypothesis = '',
    required this.description,
    required this.budget,
    required this.timePlan,
    this.timelinePhases = const <PlanPhase>[],
    this.validation,
    this.stepsSectionSourceRefs = const <PlanSourceRef>[],
    this.materialsSectionSourceRefs = const <PlanSourceRef>[],
    this.risks = const <PlanRisk>[],
  });

  /// Primary scientific hypothesis when provided by the backend.
  final String hypothesis;
  final String description;
  final Budget budget;
  final TimePlan timePlan;

  /// Backend timeline phases (duration + dependencies); drives the plan timeline bar.
  final List<PlanPhase> timelinePhases;

  final PlanValidation? validation;

  /// Source references for the Steps section header as a whole.
  final List<PlanSourceRef> stepsSectionSourceRefs;

  /// Source references for the Materials section header as a whole.
  final List<PlanSourceRef> materialsSectionSourceRefs;

  /// Risks associated with this plan.
  final List<PlanRisk> risks;

  ExperimentPlan copyWith({
    String? hypothesis,
    String? description,
    Budget? budget,
    TimePlan? timePlan,
    List<PlanPhase>? timelinePhases,
    PlanValidation? validation,
    bool clearValidation = false,
    List<PlanSourceRef>? stepsSectionSourceRefs,
    List<PlanSourceRef>? materialsSectionSourceRefs,
    List<PlanRisk>? risks,
  }) {
    return ExperimentPlan(
      hypothesis: hypothesis ?? this.hypothesis,
      description: description ?? this.description,
      budget: budget ?? this.budget,
      timePlan: timePlan ?? this.timePlan,
      timelinePhases: timelinePhases ?? this.timelinePhases,
      validation:
          clearValidation ? null : (validation ?? this.validation),
      stepsSectionSourceRefs:
          stepsSectionSourceRefs ?? this.stepsSectionSourceRefs,
      materialsSectionSourceRefs:
          materialsSectionSourceRefs ?? this.materialsSectionSourceRefs,
      risks: risks ?? this.risks,
    );
  }
}

/// Snapshot of [plan] so an ongoing project keeps a stable copy of the plan.
ExperimentPlan deepCopyExperimentPlan(ExperimentPlan plan) {
  return ExperimentPlan(
    hypothesis: plan.hypothesis,
    description: plan.description,
    timelinePhases: <PlanPhase>[
      for (final PlanPhase p in plan.timelinePhases)
        PlanPhase(
          phase: p.phase,
          durationDays: p.durationDays,
          dependsOn: List<String>.from(p.dependsOn),
        ),
    ],
    validation: plan.validation == null
        ? null
        : PlanValidation(
            successMetrics: List<String>.from(plan.validation!.successMetrics),
            failureMetrics: List<String>.from(plan.validation!.failureMetrics),
            miqeCompliance: plan.validation!.miqeCompliance,
          ),
    stepsSectionSourceRefs:
        List<PlanSourceRef>.from(plan.stepsSectionSourceRefs),
    materialsSectionSourceRefs:
        List<PlanSourceRef>.from(plan.materialsSectionSourceRefs),
    risks: <PlanRisk>[
      for (final PlanRisk r in plan.risks) r.copyWith(),
    ],
    budget: Budget(
      total: plan.budget.total,
      materials: <Material>[
        for (final Material m in plan.budget.materials) m.copyWith(),
      ],
    ),
    timePlan: TimePlan(
      totalDuration: plan.timePlan.totalDuration,
      steps: <Step>[
        for (final Step s in plan.timePlan.steps) s.copyWith(),
      ],
    ),
  );
}

class Budget {
  const Budget({
    required this.total,
    required this.materials,
  });

  final double total;
  final List<Material> materials;

  Budget copyWith({
    double? total,
    List<Material>? materials,
  }) {
    return Budget(
      total: total ?? this.total,
      materials: materials ?? this.materials,
    );
  }
}

class Material {
  const Material({
    required this.id,
    required this.title,
    required this.catalogNumber,
    required this.description,
    required this.amount,
    required this.price,
    this.sourceRefs = const <PlanSourceRef>[],
    this.reagent,
    this.vendor,
    this.sku,
    this.qty,
    this.qtyUnit,
    this.unitCostUsd,
    this.notes,
    this.tier,
    this.verified,
    this.verificationUrl,
    this.confidence,
  });

  factory Material.blank() {
    return Material(
      id: generateLocalId('mat'),
      title: 'New material',
      catalogNumber: '',
      description: '',
      amount: 1,
      price: 0,
    );
  }

  final String id;
  final String title;
  final String catalogNumber;
  final String description;
  final int amount;
  final double price;
  final List<PlanSourceRef> sourceRefs;

  final String? reagent;
  final String? vendor;
  final String? sku;
  final int? qty;
  final String? qtyUnit;
  final double? unitCostUsd;
  final String? notes;
  final String? tier;
  final bool? verified;
  final String? verificationUrl;
  final String? confidence;

  Material copyWith({
    String? id,
    String? title,
    String? catalogNumber,
    String? description,
    int? amount,
    double? price,
    List<PlanSourceRef>? sourceRefs,
    String? reagent,
    String? vendor,
    String? sku,
    int? qty,
    String? qtyUnit,
    double? unitCostUsd,
    String? notes,
    String? tier,
    bool? verified,
    String? verificationUrl,
    String? confidence,
    bool clearBeFields = false,
  }) {
    return Material(
      id: id ?? this.id,
      title: title ?? this.title,
      catalogNumber: catalogNumber ?? this.catalogNumber,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      price: price ?? this.price,
      sourceRefs: sourceRefs ?? this.sourceRefs,
      reagent: clearBeFields ? null : (reagent ?? this.reagent),
      vendor: clearBeFields ? null : (vendor ?? this.vendor),
      sku: clearBeFields ? null : (sku ?? this.sku),
      qty: clearBeFields ? null : (qty ?? this.qty),
      qtyUnit: clearBeFields ? null : (qtyUnit ?? this.qtyUnit),
      unitCostUsd: clearBeFields ? null : (unitCostUsd ?? this.unitCostUsd),
      notes: clearBeFields ? null : (notes ?? this.notes),
      tier: clearBeFields ? null : (tier ?? this.tier),
      verified: clearBeFields ? null : (verified ?? this.verified),
      verificationUrl:
          clearBeFields ? null : (verificationUrl ?? this.verificationUrl),
      confidence: clearBeFields ? null : (confidence ?? this.confidence),
    );
  }
}

class TimePlan {
  const TimePlan({
    required this.totalDuration,
    required this.steps,
  });

  final Duration totalDuration;
  final List<Step> steps;

  TimePlan copyWith({
    Duration? totalDuration,
    List<Step>? steps,
  }) {
    return TimePlan(
      totalDuration: totalDuration ?? this.totalDuration,
      steps: steps ?? this.steps,
    );
  }
}

class Step {
  const Step({
    required this.id,
    required this.number,
    required this.duration,
    required this.name,
    required this.description,
    this.dependsOn = const <String>[],
    this.milestone,
    this.sourceRefs = const <PlanSourceRef>[],
  });

  factory Step.blank({required int number}) {
    return Step(
      id: generateLocalId('step'),
      number: number,
      duration: const Duration(days: 1),
      name: 'New step',
      description: '',
      dependsOn: const <String>[],
    );
  }

  final String id;
  final int number;
  final Duration duration;
  final String name;
  final String description;
  /// Predecessor step names (e.g. timeline phase titles), matching backend `depends_on`.
  final List<String> dependsOn;
  final String? milestone;
  final List<PlanSourceRef> sourceRefs;

  bool get isMilestone => milestone != null;

  Step copyWith({
    String? id,
    int? number,
    Duration? duration,
    String? name,
    String? description,
    List<String>? dependsOn,
    String? milestone,
    bool clearMilestone = false,
    List<PlanSourceRef>? sourceRefs,
  }) {
    return Step(
      id: id ?? this.id,
      number: number ?? this.number,
      duration: duration ?? this.duration,
      name: name ?? this.name,
      description: description ?? this.description,
      dependsOn: dependsOn ?? this.dependsOn,
      milestone: clearMilestone ? null : (milestone ?? this.milestone),
      sourceRefs: sourceRefs ?? this.sourceRefs,
    );
  }
}

/// Returns true if any source ref in the plan is a [PreviousLearningSourceRef].
bool planHasPreviousLearning(ExperimentPlan plan) {
  bool hasRef(List<PlanSourceRef> refs) =>
      refs.any((PlanSourceRef r) => r is PreviousLearningSourceRef);
  return hasRef(plan.stepsSectionSourceRefs) ||
      hasRef(plan.materialsSectionSourceRefs) ||
      plan.timePlan.steps.any((Step s) => hasRef(s.sourceRefs)) ||
      plan.budget.materials.any((Material m) => hasRef(m.sourceRefs));
}
