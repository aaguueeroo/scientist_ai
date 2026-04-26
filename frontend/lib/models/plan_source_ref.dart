sealed class PlanSourceRef {
  const PlanSourceRef();
}

/// A reference to a paper in the literature review list. [referenceIndex] is
/// 1-based and matches the order of sources in [LiteratureReview.sources].
class LiteratureSourceRef extends PlanSourceRef {
  const LiteratureSourceRef({required this.referenceIndex});

  final int referenceIndex;

  @override
  bool operator ==(Object other) =>
      other is LiteratureSourceRef && other.referenceIndex == referenceIndex;

  @override
  int get hashCode => referenceIndex.hashCode;
}

/// A reference to knowledge extracted from a previous Marie session.
class PreviousLearningSourceRef extends PlanSourceRef {
  const PreviousLearningSourceRef();

  @override
  bool operator ==(Object other) => other is PreviousLearningSourceRef;

  @override
  int get hashCode => runtimeType.hashCode;
}
