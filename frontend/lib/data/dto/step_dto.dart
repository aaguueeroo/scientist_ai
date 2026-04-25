class StepDto {
  const StepDto({
    required this.number,
    required this.durationSeconds,
    required this.name,
    required this.description,
    this.milestone,
    this.id,
  });

  factory StepDto.fromJson(Map<String, dynamic> json) {
    return StepDto(
      number: (json['number'] as num).toInt(),
      durationSeconds: (json['duration_seconds'] as num).toInt(),
      name: json['name'] as String,
      description: json['description'] as String,
      milestone: json['milestone'] as String?,
      id: json['id'] as String?,
    );
  }

  final int number;
  final int durationSeconds;
  final String name;
  final String description;
  final String? milestone;

  /// Optional FE-stable id. Sent over the wire only when round-tripping
  /// embedded plan snapshots (e.g. inside a `Review`). The base
  /// `/experiment-plan` endpoint omits it.
  final String? id;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'number': number,
      'duration_seconds': durationSeconds,
      'name': name,
      'description': description,
      'milestone': milestone,
      if (id != null) 'id': id,
    };
  }
}
