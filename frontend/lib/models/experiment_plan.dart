import '../core/id_generator.dart';
import 'plan_source_ref.dart';

enum PlanRiskLikelihood { low, medium, high }

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
    required this.description,
    required this.budget,
    required this.timePlan,
    this.stepsSectionSourceRefs = const <PlanSourceRef>[],
    this.materialsSectionSourceRefs = const <PlanSourceRef>[],
    this.risks = const <PlanRisk>[],
  });

  final String description;
  final Budget budget;
  final TimePlan timePlan;

  /// Source references for the Steps section header as a whole.
  final List<PlanSourceRef> stepsSectionSourceRefs;

  /// Source references for the Materials section header as a whole.
  final List<PlanSourceRef> materialsSectionSourceRefs;

  /// Risks associated with this plan.
  final List<PlanRisk> risks;

  ExperimentPlan copyWith({
    String? description,
    Budget? budget,
    TimePlan? timePlan,
    List<PlanSourceRef>? stepsSectionSourceRefs,
    List<PlanSourceRef>? materialsSectionSourceRefs,
    List<PlanRisk>? risks,
  }) {
    return ExperimentPlan(
      description: description ?? this.description,
      budget: budget ?? this.budget,
      timePlan: timePlan ?? this.timePlan,
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
    description: plan.description,
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

  Material copyWith({
    String? id,
    String? title,
    String? catalogNumber,
    String? description,
    int? amount,
    double? price,
    List<PlanSourceRef>? sourceRefs,
  }) {
    return Material(
      id: id ?? this.id,
      title: title ?? this.title,
      catalogNumber: catalogNumber ?? this.catalogNumber,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      price: price ?? this.price,
      sourceRefs: sourceRefs ?? this.sourceRefs,
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
    );
  }

  final String id;
  final int number;
  final Duration duration;
  final String name;
  final String description;
  final String? milestone;
  final List<PlanSourceRef> sourceRefs;

  bool get isMilestone => milestone != null;

  Step copyWith({
    String? id,
    int? number,
    Duration? duration,
    String? name,
    String? description,
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
