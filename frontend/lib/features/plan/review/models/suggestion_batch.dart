import 'package:flutter/material.dart' show Color;

import 'batch_status.dart';
import 'plan_change.dart';

class SuggestionBatch {
  const SuggestionBatch({
    required this.id,
    required this.authorId,
    required this.createdAt,
    required this.color,
    required this.status,
    required this.changes,
  });

  final String id;
  final String authorId;
  final DateTime createdAt;
  final Color color;
  final BatchStatus status;
  final List<PlanChange> changes;

  bool get isEmpty => changes.isEmpty;

  SuggestionBatch copyWith({
    BatchStatus? status,
  }) {
    return SuggestionBatch(
      id: id,
      authorId: authorId,
      createdAt: createdAt,
      color: color,
      status: status ?? this.status,
      changes: changes,
    );
  }
}
