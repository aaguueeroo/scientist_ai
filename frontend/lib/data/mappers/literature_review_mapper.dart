import '../../models/literature_review.dart';
import '../dto/literature_review_event_dto.dart';
import '../dto/source_dto.dart';

class LiteratureReviewMapper {
  const LiteratureReviewMapper._();

  static LiteratureReview toDomain(LiteratureReviewEventDto event) {
    return LiteratureReview(
      doesSimilarWorkExist: event.doesSimilarWorkExist,
      sources: event.sources.map(_sourceToDomain).toList(),
      totalSources: event.expectedTotalSources,
    );
  }

  static Source _sourceToDomain(SourceDto dto) {
    return Source(
      author: dto.author,
      title: dto.title,
      dateOfPublication: DateTime.parse(dto.dateOfPublication),
      abstractText: dto.abstractText,
      doi: dto.doi,
      score: (dto.score ?? 0.0).clamp(0.0, 1.0),
      isVerified: dto.isVerified ?? false,
    );
  }
}
