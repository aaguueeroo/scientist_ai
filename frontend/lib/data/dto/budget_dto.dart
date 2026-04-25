import 'material_dto.dart';

class BudgetDto {
  const BudgetDto({
    required this.total,
    required this.currency,
    required this.materials,
  });

  factory BudgetDto.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawMaterials =
        (json['materials'] as List<dynamic>? ?? <dynamic>[]);
    return BudgetDto(
      total: (json['total'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'USD',
      materials: rawMaterials
          .map((dynamic e) => MaterialDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final double total;
  final String currency;
  final List<MaterialDto> materials;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'total': total,
      'currency': currency,
      'materials': materials.map((MaterialDto m) => m.toJson()).toList(),
    };
  }
}
