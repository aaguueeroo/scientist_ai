import 'plan_reference_dto.dart';
import 'risk_dto.dart';

class BackendExperimentPlanDto {
  const BackendExperimentPlanDto({
    this.planId,
    this.hypothesis,
    this.novelty,
    this.references = const <PlanReferenceDto>[],
    this.protocol = const <ProtocolStepDto>[],
    this.materials = const <BackendMaterialDto>[],
    this.budget,
    this.timeline = const <TimelineEntryDto>[],
    this.validation,
    this.risks = const <RiskDto>[],
    this.confidence,
    this.groundingSummary,
  });

  factory BackendExperimentPlanDto.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawRefs =
        json['references'] as List<dynamic>? ?? <dynamic>[];
    final List<dynamic> rawProto =
        json['protocol'] as List<dynamic>? ?? <dynamic>[];
    final List<dynamic> rawMat =
        json['materials'] as List<dynamic>? ?? <dynamic>[];
    final List<dynamic> rawTime =
        json['timeline'] as List<dynamic>? ?? <dynamic>[];
    final List<dynamic> rawRisks =
        json['risks'] as List<dynamic>? ?? <dynamic>[];
    return BackendExperimentPlanDto(
      planId: json['plan_id'] as String?,
      hypothesis: json['hypothesis'] as String?,
      novelty: json['novelty'] as String?,
      references: rawRefs
          .map(
            (dynamic e) =>
                PlanReferenceDto.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      protocol: rawProto
          .map(
            (dynamic e) => ProtocolStepDto.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      materials: rawMat
          .map(
            (dynamic e) =>
                BackendMaterialDto.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      budget: json['budget'] == null
          ? null
          : BackendBudgetDto.fromJson(json['budget'] as Map<String, dynamic>),
      timeline: rawTime
          .map(
            (dynamic e) =>
                TimelineEntryDto.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      validation: json['validation'] == null
          ? null
          : PlanValidationDto.fromJson(
              json['validation'] as Map<String, dynamic>,
            ),
      risks: rawRisks
          .map((dynamic e) => RiskDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      confidence: json['confidence'] as String?,
      groundingSummary: json['grounding_summary'] == null
          ? null
          : json['grounding_summary'] as Map<String, dynamic>?,
    );
  }

  final String? planId;
  final String? hypothesis;
  final String? novelty;
  final List<PlanReferenceDto> references;
  final List<ProtocolStepDto> protocol;
  final List<BackendMaterialDto> materials;
  final BackendBudgetDto? budget;
  final List<TimelineEntryDto> timeline;
  final PlanValidationDto? validation;
  final List<RiskDto> risks;
  final String? confidence;
  final Map<String, dynamic>? groundingSummary;
}

class ProtocolStepDto {
  const ProtocolStepDto({
    required this.order,
    required this.technique,
    required this.description,
    this.sourceDoi,
    this.sourceUrl,
    this.tier,
    this.verified = false,
    this.verificationUrl,
    this.confidence,
    this.notes,
  });

  factory ProtocolStepDto.fromJson(Map<String, dynamic> json) {
    return ProtocolStepDto(
      order: (json['order'] as num?)?.toInt() ?? 0,
      technique: json['technique'] as String? ?? '',
      description: json['description'] as String? ?? '',
      sourceDoi: json['source_doi'] as String?,
      sourceUrl: json['source_url'] as String?,
      tier: json['tier'] as String?,
      verified: json['verified'] as bool? ?? false,
      verificationUrl: json['verification_url'] as String?,
      confidence: json['confidence'] as String?,
      notes: json['notes'] as String?,
    );
  }

  final int order;
  final String technique;
  final String description;
  final String? sourceDoi;
  final String? sourceUrl;
  final String? tier;
  final bool verified;
  final String? verificationUrl;
  final String? confidence;
  final String? notes;
}

class BackendMaterialDto {
  const BackendMaterialDto({
    required this.reagent,
    this.vendor,
    this.sku,
    this.qty,
    this.qtyUnit,
    this.unitCostUsd,
    this.sourceUrl,
    this.notes,
    this.tier,
    this.verified = false,
    this.verificationUrl,
    this.confidence,
  });

  factory BackendMaterialDto.fromJson(Map<String, dynamic> json) {
    return BackendMaterialDto(
      reagent: json['reagent'] as String? ?? '',
      vendor: json['vendor'] as String?,
      sku: json['sku'] as String?,
      qty: (json['qty'] as num?)?.toInt(),
      qtyUnit: json['qty_unit'] as String?,
      unitCostUsd: (json['unit_cost_usd'] as num?)?.toDouble(),
      sourceUrl: json['source_url'] as String?,
      notes: json['notes'] as String?,
      tier: json['tier'] as String?,
      verified: json['verified'] as bool? ?? false,
      verificationUrl: json['verification_url'] as String?,
      confidence: json['confidence'] as String?,
    );
  }

  final String reagent;
  final String? vendor;
  final String? sku;
  final int? qty;
  final String? qtyUnit;
  final double? unitCostUsd;
  final String? sourceUrl;
  final String? notes;
  final String? tier;
  final bool verified;
  final String? verificationUrl;
  final String? confidence;
}

class BackendBudgetDto {
  const BackendBudgetDto({
    required this.items,
    required this.totalUsd,
    this.currency = 'USD',
  });

  factory BackendBudgetDto.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw =
        json['items'] as List<dynamic>? ?? <dynamic>[];
    return BackendBudgetDto(
      items: raw
          .map(
            (dynamic e) => BudgetItemDto.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      totalUsd: (json['total_usd'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'USD',
    );
  }

  final List<BudgetItemDto> items;
  final double totalUsd;
  final String currency;
}

class BudgetItemDto {
  const BudgetItemDto({
    required this.label,
    required this.costUsd,
  });

  factory BudgetItemDto.fromJson(Map<String, dynamic> json) {
    return BudgetItemDto(
      label: json['label'] as String? ?? '',
      costUsd: (json['cost_usd'] as num?)?.toDouble() ?? 0,
    );
  }

  final String label;
  final double costUsd;
}

class TimelineEntryDto {
  const TimelineEntryDto({
    required this.phase,
    required this.durationDays,
    this.dependsOn = const <String>[],
  });

  factory TimelineEntryDto.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawDep =
        json['depends_on'] as List<dynamic>? ?? <dynamic>[];
    return TimelineEntryDto(
      phase: json['phase'] as String? ?? '',
      durationDays: (json['duration_days'] as num?)?.toInt() ?? 0,
      dependsOn: rawDep.map((dynamic e) => e as String).toList(),
    );
  }

  final String phase;
  final int durationDays;
  final List<String> dependsOn;
}

class PlanValidationDto {
  const PlanValidationDto({
    this.successMetrics = const <String>[],
    this.failureMetrics = const <String>[],
    this.miqeCompliance,
  });

  factory PlanValidationDto.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawS =
        json['success_metrics'] as List<dynamic>? ?? <dynamic>[];
    final List<dynamic> rawF =
        json['failure_metrics'] as List<dynamic>? ?? <dynamic>[];
    return PlanValidationDto(
      successMetrics: rawS.map((dynamic e) => e as String).toList(),
      failureMetrics: rawF.map((dynamic e) => e as String).toList(),
      miqeCompliance: json['miqe_compliance'] as String?,
    );
  }

  final List<String> successMetrics;
  final List<String> failureMetrics;
  final String? miqeCompliance;
}
