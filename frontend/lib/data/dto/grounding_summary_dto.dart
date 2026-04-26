class GroundingSummaryDto {
  const GroundingSummaryDto({
    required this.verifiedCount,
    required this.unverifiedCount,
    this.tier0Drops = 0,
    this.groundingCaveat,
  });

  factory GroundingSummaryDto.fromJson(Map<String, dynamic> json) {
    final String? c = json['grounding_caveat'] as String?;
    return GroundingSummaryDto(
      verifiedCount: (json['verified_count'] as num?)?.toInt() ?? 0,
      unverifiedCount: (json['unverified_count'] as num?)?.toInt() ?? 0,
      tier0Drops: (json['tier_0_drops'] as num?)?.toInt() ?? 0,
      groundingCaveat: (c != null && c.isNotEmpty) ? c : null,
    );
  }

  final int verifiedCount;
  final int unverifiedCount;
  final int tier0Drops;
  final String? groundingCaveat;
}
