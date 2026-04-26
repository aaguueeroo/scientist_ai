import '../../features/plan/review/models/change_target.dart';
import '../../features/plan/review/models/feedback_polarity.dart';
import '../../features/plan/review/models/material_field.dart';
import '../../features/plan/review/models/review_section.dart';
import '../../features/plan/review/models/step_field.dart';
import '../../features/review/models/change_target_codec.dart';
import '../../features/review/models/review.dart';
import '../../features/review/models/review_kind.dart';
import '../../models/experiment_plan.dart';
import '../dto/review_dto.dart';
import 'experiment_plan_mapper.dart';

/// Maps between [Review] domain objects and [ReviewDto] wire objects.
class ReviewMapper {
  const ReviewMapper._();

  static Review toDomain(ReviewDto dto) {
    final ReviewKind kind = _kindFromString(dto.kind);
    switch (kind) {
      case ReviewKind.correction:
        return _correctionFromDto(dto);
      case ReviewKind.comment:
        return _commentFromDto(dto);
      case ReviewKind.feedback:
        return _feedbackFromDto(dto);
    }
  }

  static ReviewDto fromDomain(Review review) {
    return ReviewDto(
      id: review.id,
      createdAt: review.createdAt.toUtc().toIso8601String(),
      conversationId: review.conversationId,
      query: review.query,
      originalPlan: ExperimentPlanMapper.fromDomain(review.originalPlan),
      kind: _kindToString(review.kind),
      payload: _payloadFromDomain(review),
    );
  }

  static CorrectionReview _correctionFromDto(ReviewDto dto) {
    final Map<String, dynamic> payload = dto.payload;
    final String address = payload['target'] as String;
    final ChangeTarget? target = ChangeTargetCodec.decode(address);
    if (target == null) {
      throw FormatException('Unknown correction target: $address');
    }
    return CorrectionReview(
      id: dto.id,
      conversationId: dto.conversationId,
      query: dto.query,
      originalPlan: ExperimentPlanMapper.toDomain(dto.originalPlan),
      createdAt: DateTime.parse(dto.createdAt),
      target: target,
      before: _decodeFieldValue(target, payload['before']),
      after: _decodeFieldValue(target, payload['after']),
    );
  }

  static CommentReview _commentFromDto(ReviewDto dto) {
    final Map<String, dynamic> payload = dto.payload;
    final String address = payload['target'] as String;
    final ChangeTarget? target = ChangeTargetCodec.decode(address);
    if (target == null) {
      throw FormatException('Unknown comment target: $address');
    }
    return CommentReview(
      id: dto.id,
      conversationId: dto.conversationId,
      query: dto.query,
      originalPlan: ExperimentPlanMapper.toDomain(dto.originalPlan),
      createdAt: DateTime.parse(dto.createdAt),
      target: target,
      quote: payload['quote'] as String,
      start: (payload['start'] as num).toInt(),
      end: (payload['end'] as num).toInt(),
      body: payload['body'] as String,
    );
  }

  static FeedbackReview _feedbackFromDto(ReviewDto dto) {
    final Map<String, dynamic> payload = dto.payload;
    final ReviewSection? section =
        _sectionFromString(payload['section'] as String);
    if (section == null) {
      throw FormatException('Unknown review section: ${payload['section']}');
    }
    final FeedbackPolarity? polarity =
        _polarityFromString(payload['polarity'] as String);
    if (polarity == null) {
      throw FormatException(
        'Unknown feedback polarity: ${payload['polarity']}',
      );
    }
    return FeedbackReview(
      id: dto.id,
      conversationId: dto.conversationId,
      query: dto.query,
      originalPlan: ExperimentPlanMapper.toDomain(dto.originalPlan),
      createdAt: DateTime.parse(dto.createdAt),
      section: section,
      polarity: polarity,
    );
  }

  static Map<String, dynamic> _payloadFromDomain(Review review) {
    if (review is CorrectionReview) {
      return <String, dynamic>{
        'target': ChangeTargetCodec.encode(review.target),
        'before': _encodeFieldValue(review.target, review.before),
        'after': _encodeFieldValue(review.target, review.after),
      };
    }
    if (review is CommentReview) {
      return <String, dynamic>{
        'target': ChangeTargetCodec.encode(review.target),
        'quote': review.quote,
        'start': review.start,
        'end': review.end,
        'body': review.body,
      };
    }
    if (review is FeedbackReview) {
      return <String, dynamic>{
        'section': review.section.name,
        'polarity': review.polarity.name,
      };
    }
    return <String, dynamic>{};
  }

  /// Encodes runtime values to JSON-friendly primitives. Durations become
  /// integer seconds; [Step] and [Material] objects become maps for
  /// structural correction reviews (insertions/removals). Everything else
  /// passes through.
  static Object? _encodeFieldValue(ChangeTarget target, Object? value) {
    if (value == null) return null;
    if (value is Duration) return value.inSeconds;
    if (value is Step) return _encodeStep(value);
    if (value is Material) return _encodeMaterial(value);
    return value;
  }

  /// Inverse of [_encodeFieldValue]. Uses [target] to decide the coercion:
  /// Durations from seconds, and Step/Material objects from their map
  /// representations (used for insertion/removal correction reviews).
  static Object? _decodeFieldValue(ChangeTarget target, Object? raw) {
    if (raw == null) return null;
    if (target is TotalDurationTarget && raw is num) {
      return Duration(seconds: raw.toInt());
    }
    if (target is StepFieldTarget) {
      if (target.field == StepField.duration && raw is num) {
        return Duration(seconds: raw.toInt());
      }
      if (raw is Map) {
        return _decodeStep(Map<String, dynamic>.from(raw));
      }
    }
    if (target is MaterialFieldTarget) {
      if (raw is Map) {
        return _decodeMaterial(Map<String, dynamic>.from(raw));
      }
      switch (target.field) {
        case MaterialField.amount:
          if (raw is num) return raw.toInt();
          return raw;
        case MaterialField.price:
          if (raw is num) return raw.toDouble();
          return raw;
        case MaterialField.title:
        case MaterialField.catalogNumber:
        case MaterialField.description:
          return raw;
      }
    }
    if (target is BudgetTotalTarget && raw is num) {
      return raw.toDouble();
    }
    return raw;
  }

  static Map<String, dynamic> _encodeStep(Step step) {
    return <String, dynamic>{
      'id': step.id,
      'number': step.number,
      'duration_seconds': step.duration.inSeconds,
      'name': step.name,
      'description': step.description,
      'milestone': step.milestone,
    };
  }

  static Step _decodeStep(Map<String, dynamic> raw) {
    return Step(
      id: raw['id'] as String,
      number: (raw['number'] as num).toInt(),
      duration: Duration(seconds: (raw['duration_seconds'] as num).toInt()),
      name: raw['name'] as String,
      description: raw['description'] as String,
      milestone: raw['milestone'] as String?,
    );
  }

  static Map<String, dynamic> _encodeMaterial(Material material) {
    return <String, dynamic>{
      'id': material.id,
      'title': material.title,
      'catalog_number': material.catalogNumber,
      'description': material.description,
      'amount': material.amount,
      'price': material.price,
    };
  }

  static Material _decodeMaterial(Map<String, dynamic> raw) {
    return Material(
      id: raw['id'] as String,
      title: raw['title'] as String,
      catalogNumber: raw['catalog_number'] as String,
      description: raw['description'] as String,
      amount: (raw['amount'] as num).toInt(),
      price: (raw['price'] as num).toDouble(),
    );
  }

  static ReviewKind _kindFromString(String raw) {
    switch (raw) {
      case 'correction':
        return ReviewKind.correction;
      case 'comment':
        return ReviewKind.comment;
      case 'feedback':
        return ReviewKind.feedback;
    }
    throw FormatException('Unknown review kind: $raw');
  }

  static String _kindToString(ReviewKind kind) {
    switch (kind) {
      case ReviewKind.correction:
        return 'correction';
      case ReviewKind.comment:
        return 'comment';
      case ReviewKind.feedback:
        return 'feedback';
    }
  }

  static ReviewSection? _sectionFromString(String raw) {
    for (final ReviewSection s in ReviewSection.values) {
      if (s.name == raw) return s;
    }
    return null;
  }

  static FeedbackPolarity? _polarityFromString(String raw) {
    for (final FeedbackPolarity p in FeedbackPolarity.values) {
      if (p.name == raw) return p;
    }
    return null;
  }
}
