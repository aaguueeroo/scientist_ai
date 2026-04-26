import 'comment_anchor.dart';

class PlanComment {
  const PlanComment({
    required this.id,
    required this.authorId,
    required this.createdAt,
    required this.anchor,
    required this.body,
    this.isResolved = false,
  });

  final String id;
  final String authorId;
  final DateTime createdAt;
  final CommentAnchor anchor;
  final String body;
  final bool isResolved;

  PlanComment copyWith({
    CommentAnchor? anchor,
    String? body,
    bool? isResolved,
  }) {
    return PlanComment(
      id: id,
      authorId: authorId,
      createdAt: createdAt,
      anchor: anchor ?? this.anchor,
      body: body ?? this.body,
      isResolved: isResolved ?? this.isResolved,
    );
  }
}
