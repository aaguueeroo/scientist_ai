class SourceDto {
  const SourceDto({
    required this.author,
    required this.title,
    required this.dateOfPublication,
    required this.abstractText,
    required this.doi,
    this.score,
    this.isVerified,
  });

  factory SourceDto.fromJson(Map<String, dynamic> json) {
    return SourceDto(
      author: json['author'] as String,
      title: json['title'] as String,
      dateOfPublication: json['date_of_publication'] as String,
      abstractText: json['abstract'] as String,
      doi: json['doi'] as String,
      score: (json['score'] as num?)?.toDouble(),
      isVerified: json['is_verified'] as bool?,
    );
  }

  final String author;
  final String title;
  // ISO 8601 date (YYYY-MM-DD).
  final String dateOfPublication;
  final String abstractText;
  final String doi;
  final double? score;
  final bool? isVerified;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'author': author,
      'title': title,
      'date_of_publication': dateOfPublication,
      'abstract': abstractText,
      'doi': doi,
      'score': score,
      'is_verified': isVerified,
    };
  }
}
