import 'material_dto.dart';

class BudgetDto {
  const BudgetDto({
    required this.total,
    required this.currency,
    required this.materials,
  });

  factory BudgetDto.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('items')) {
      final List<dynamic> rawItems =
          json['items'] as List<dynamic>? ?? <dynamic>[];
      final List<MaterialDto> lineItems = rawItems.map((dynamic e) {
        final Map<String, dynamic> m = e as Map<String, dynamic>;
        final String label = m['label'] as String? ?? '';
        final double cost = (m['cost_usd'] as num?)?.toDouble() ?? 0;
        return MaterialDto(
          title: label,
          catalogNumber: '',
          description: '',
          amount: 1,
          price: cost,
        );
      }).toList();
      final double totalUsd =
          (json['total_usd'] as num?)?.toDouble() ??
          lineItems.fold<double>(
            0,
            (double sum, MaterialDto m) => sum + m.price,
          );
      return BudgetDto(
        total: totalUsd,
        currency: json['currency'] as String? ?? 'USD',
        materials: lineItems,
      );
    }
    final List<dynamic> rawMaterials =
        json['materials'] as List<dynamic>? ?? <dynamic>[];
    return BudgetDto(
      total: (json['total'] as num?)?.toDouble() ?? 0,
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
    final bool hasBeShape = materials.any((MaterialDto m) => m.reagent != null);
    if (hasBeShape) {
      return <String, dynamic>{
        'total_usd': total,
        'currency': currency,
        'items': materials
            .map(
              (MaterialDto m) => <String, dynamic>{
                'label': m.title,
                'cost_usd': m.price,
              },
            )
            .toList(),
      };
    }
    return <String, dynamic>{
      'total': total,
      'currency': currency,
      'materials': materials.map((MaterialDto m) => m.toJson()).toList(),
    };
  }
}
