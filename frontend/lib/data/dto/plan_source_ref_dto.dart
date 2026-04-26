import '../../models/plan_source_ref.dart';

class PlanSourceRefDto {
  const PlanSourceRefDto({
    required this.kind,
    this.referenceIndex,
  });

  factory PlanSourceRefDto.fromJson(Map<String, dynamic> json) {
    return PlanSourceRefDto(
      kind: json['kind'] as String? ?? 'previous_learning',
      referenceIndex: json['reference_index'] as int?,
    );
  }

  final String kind;
  final int? referenceIndex;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'kind': kind,
      if (referenceIndex != null) 'reference_index': referenceIndex,
    };
  }

  PlanSourceRef toDomain() {
    if (kind == 'literature') {
      final int idx = referenceIndex ?? 1;
      return LiteratureSourceRef(referenceIndex: idx);
    }
    return const PreviousLearningSourceRef();
  }

  static PlanSourceRefDto fromDomain(PlanSourceRef ref) {
    return switch (ref) {
      LiteratureSourceRef(referenceIndex: final int idx) =>
        PlanSourceRefDto(kind: 'literature', referenceIndex: idx),
      PreviousLearningSourceRef() =>
        const PlanSourceRefDto(kind: 'previous_learning'),
    };
  }

  static List<PlanSourceRef> listFromJson(dynamic json) {
    if (json == null) {
      return const <PlanSourceRef>[];
    }
    if (json is! List<dynamic>) {
      return const <PlanSourceRef>[];
    }
    return json
        .map(
          (dynamic item) =>
              PlanSourceRefDto.fromJson(item as Map<String, dynamic>)
                  .toDomain(),
        )
        .toList(growable: false);
  }

  static List<Map<String, dynamic>> listToJson(List<PlanSourceRef> refs) {
    return refs
        .map((PlanSourceRef r) => fromDomain(r).toJson())
        .toList(growable: false);
  }
}
