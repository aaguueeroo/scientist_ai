import 'change_target.dart';

class CommentAnchor {
  const CommentAnchor({
    required this.target,
    required this.quote,
    required this.start,
    required this.end,
  });

  final ChangeTarget target;
  final String quote;
  final int start;
  final int end;

  CommentAnchor copyWith({
    int? start,
    int? end,
  }) {
    return CommentAnchor(
      target: target,
      quote: quote,
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }
}
