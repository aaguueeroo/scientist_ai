import 'package:flutter/foundation.dart';

import '../features/review/models/review.dart';
import '../repositories/scientist_repository.dart';

/// Global, persisted store of every correction, comment, and like/dislike
/// the user has ever given the AI. Backed by `POST /reviews` and
/// `GET /reviews`.
///
/// Errors never block the UI: optimistic inserts are rolled back on
/// failure and `submitError` / `loadError` carry a friendly message.
class ReviewStoreController extends ChangeNotifier {
  ReviewStoreController({required ScientistRepository repository})
      : _repository = repository;

  final ScientistRepository _repository;

  final List<Review> _reviews = <Review>[];
  bool _isLoading = false;
  String? _loadError;
  String? _submitError;

  List<Review> get reviews => List<Review>.unmodifiable(_reviews);
  bool get isLoading => _isLoading;
  String? get loadError => _loadError;
  String? get submitError => _submitError;
  bool get isEmpty => _reviews.isEmpty;

  /// Loads every persisted review for the current user. Safe to call
  /// multiple times (each call replaces the in-memory list).
  Future<void> loadReviews() async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      final List<Review> next = await _repository.fetchReviews();
      _reviews
        ..clear()
        ..addAll(next);
    } catch (err, stackTrace) {
      debugPrint('Load reviews error: $err\n$stackTrace');
      _loadError = 'Unable to load your reviews. Please retry.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Optimistically inserts [review] at the top of the list, then sends
  /// it to the backend. Rolls back the insertion if the request fails.
  Future<void> submitReview(Review review) async {
    _submitError = null;
    _reviews.insert(0, review);
    notifyListeners();
    try {
      final Review stored = await _repository.submitReview(review);
      final int index = _reviews.indexWhere((Review r) => r.id == review.id);
      if (index >= 0) {
        _reviews[index] = stored;
      }
      notifyListeners();
    } catch (err, stackTrace) {
      debugPrint('Submit review error: $err\n$stackTrace');
      _submitError = 'Unable to save your review. It will not appear in '
          'the Reviewer.';
      _reviews.removeWhere((Review r) => r.id == review.id);
      notifyListeners();
    }
  }

  /// Submits multiple reviews sequentially. Each one is independently
  /// rolled back on failure; partial success is allowed.
  Future<void> submitReviews(List<Review> reviews) async {
    for (final Review review in reviews) {
      await submitReview(review);
    }
  }
}
