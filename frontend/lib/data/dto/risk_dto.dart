class RiskDto {
  const RiskDto({
    required this.description,
    required this.likelihood,
    required this.mitigation,
    this.complianceNote,
  });

  factory RiskDto.fromJson(Map<String, dynamic> json) {
    return RiskDto(
      description: json['description'] as String,
      likelihood: json['likelihood'] as String? ?? 'medium',
      mitigation: json['mitigation'] as String? ?? '',
      complianceNote: json['compliance_note'] as String?,
    );
  }

  final String description;
  final String likelihood;
  final String mitigation;
  final String? complianceNote;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'description': description,
      'likelihood': likelihood,
      'mitigation': mitigation,
      if (complianceNote != null) 'compliance_note': complianceNote,
    };
  }
}
