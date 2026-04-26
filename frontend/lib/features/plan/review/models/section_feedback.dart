import 'feedback_polarity.dart';

class SectionFeedback {
  const SectionFeedback({
    required this.polarity,
    required this.authorId,
    required this.at,
  });

  final FeedbackPolarity polarity;
  final String authorId;
  final DateTime at;
}
