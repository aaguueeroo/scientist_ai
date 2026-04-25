class MaterialDto {
  const MaterialDto({
    required this.title,
    required this.catalogNumber,
    required this.description,
    required this.amount,
    required this.price,
  });

  factory MaterialDto.fromJson(Map<String, dynamic> json) {
    return MaterialDto(
      title: json['title'] as String,
      catalogNumber: json['catalog_number'] as String,
      description: json['description'] as String,
      amount: (json['amount'] as num).toInt(),
      price: (json['price'] as num).toDouble(),
    );
  }

  final String title;
  final String catalogNumber;
  final String description;
  final int amount;
  final double price;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'catalog_number': catalogNumber,
      'description': description,
      'amount': amount,
      'price': price,
    };
  }
}
