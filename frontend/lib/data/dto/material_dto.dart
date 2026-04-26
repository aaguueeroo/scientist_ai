class MaterialDto {
  const MaterialDto({
    required this.title,
    required this.catalogNumber,
    required this.description,
    required this.amount,
    required this.price,
    this.id,
    this.sourceRefs = const <Map<String, dynamic>>[],
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

  factory MaterialDto.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('reagent')) {
      final int q = (json['qty'] as num?)?.toInt() ?? 1;
      final double unit = (json['unit_cost_usd'] as num?)?.toDouble() ?? 0;
      return MaterialDto(
        title: json['reagent'] as String? ?? '',
        catalogNumber: json['sku'] as String? ?? '',
        description: json['notes'] as String? ?? '',
        amount: q,
        price: unit,
        reagent: json['reagent'] as String?,
        vendor: json['vendor'] as String?,
        sku: json['sku'] as String?,
        qty: (json['qty'] as num?)?.toInt(),
        qtyUnit: json['qty_unit'] as String?,
        unitCostUsd: (json['unit_cost_usd'] as num?)?.toDouble(),
        notes: json['notes'] as String?,
        tier: json['tier'] as String?,
        verified: json['verified'] as bool?,
        verificationUrl: json['verification_url'] as String?,
        confidence: json['confidence'] as String?,
      );
    }
    return MaterialDto(
      title: json['title'] as String? ?? '',
      catalogNumber: json['catalog_number'] as String? ?? '',
      description: json['description'] as String? ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      id: json['id'] as String?,
      sourceRefs: (json['source_refs'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          const <Map<String, dynamic>>[],
    );
  }

  final String title;
  final String catalogNumber;
  final String description;
  final int amount;
  final double price;

  /// Optional FE-stable id. Sent over the wire only when round-tripping
  /// embedded plan snapshots (e.g. inside a `Review`). The base
  /// `/experiment-plan` endpoint omits it.
  final String? id;

  /// Source references backing this material. Omitted by old API clients.
  final List<Map<String, dynamic>> sourceRefs;

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

  Map<String, dynamic> toJson() {
    if (reagent != null) {
      return <String, dynamic>{
        'reagent': reagent,
        'vendor': vendor,
        'sku': sku,
        'qty': qty,
        'qty_unit': qtyUnit,
        'unit_cost_usd': unitCostUsd,
        'notes': notes,
        'tier': tier,
        'verified': verified,
        'verification_url': verificationUrl,
        'confidence': confidence,
        if (id != null) 'id': id,
        if (sourceRefs.isNotEmpty) 'source_refs': sourceRefs,
      };
    }
    return <String, dynamic>{
      'title': title,
      'catalog_number': catalogNumber,
      'description': description,
      'amount': amount,
      'price': price,
      if (id != null) 'id': id,
      if (sourceRefs.isNotEmpty) 'source_refs': sourceRefs,
    };
  }
}
