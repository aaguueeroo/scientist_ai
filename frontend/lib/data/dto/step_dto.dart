class StepDto {
  const StepDto({
    required this.number,
    required this.durationSeconds,
    required this.name,
    required this.description,
    this.dependsOn = const <String>[],
    this.milestone,
    this.id,
    this.sourceRefs = const <Map<String, dynamic>>[],
  });

  factory StepDto.fromJson(Map<String, dynamic> json) {
    final List<dynamic>? rawDeps =
        json['depends_on'] as List<dynamic>? ?? json['dependsOn'] as List<dynamic>?;
    return StepDto(
      number: (json['number'] as num).toInt(),
      durationSeconds: (json['duration_seconds'] as num).toInt(),
      name: json['name'] as String,
      description: json['description'] as String,
      dependsOn: rawDeps == null
          ? const <String>[]
          : rawDeps.map((dynamic e) => e as String).toList(),
      milestone: json['milestone'] as String?,
      id: json['id'] as String?,
      sourceRefs: (json['source_refs'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          const <Map<String, dynamic>>[],
    );
  }

  final int number;
  final int durationSeconds;
  final String name;
  final String description;
  final List<String> dependsOn;
  final String? milestone;

  /// Optional FE-stable id. Sent over the wire only when round-tripping
  /// embedded plan snapshots (e.g. inside a `Review`). The base
  /// `/experiment-plan` endpoint omits it.
  final String? id;

  /// Source references backing this step. Omitted by old API clients.
  final List<Map<String, dynamic>> sourceRefs;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'number': number,
      'duration_seconds': durationSeconds,
      'name': name,
      'description': description,
      if (dependsOn.isNotEmpty) 'depends_on': dependsOn,
      'milestone': milestone,
      if (id != null) 'id': id,
      if (sourceRefs.isNotEmpty) 'source_refs': sourceRefs,
    };
  }
}
