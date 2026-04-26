class MaterialDto {
  const MaterialDto({
    required this.title,
    required this.catalogNumber,
    required this.description,
    required this.amount,
    required this.price,
    this.id,
    this.sourceRefs = const <Map<String, dynamic>>[],
  });

  factory MaterialDto.fromJson(Map<String, dynamic> json) {
    return MaterialDto(
      title: json['title'] as String,
      catalogNumber: json['catalog_number'] as String,
      description: json['description'] as String,
      amount: (json['amount'] as num).toInt(),
      price: (json['price'] as num).toDouble(),
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

  Map<String, dynamic> toJson() {
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
