import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;

import '../../../core/id_generator.dart';
import '../../../models/experiment_plan.dart';
import '../../review/models/review.dart' as global_review;
import '../correction/correction_format.dart';
import '../experiment_plan_view.dart' show formatExperimentPlanTotalDuration;
import 'models/batch_status.dart';
import 'models/change_target.dart';
import 'models/comment_anchor.dart';
import 'models/feedback_polarity.dart';
import 'models/material_field.dart';
import 'models/plan_change.dart';
import 'models/plan_comment.dart';
import 'models/plan_version.dart';
import 'models/removed_draft_slot.dart';
import 'models/review_section.dart';
import 'models/section_feedback.dart';
import 'models/step_field.dart';
import 'models/suggestion_batch.dart';
import 'plan_diff.dart';
import 'review_color_palette.dart';

/// Optional callback invoked by [PlanReviewController] whenever the user
/// produces new persistable feedback (corrections, comments, or
/// section feedback). Wired by `PlanReviewScaffold` to forward events to
/// the global `ReviewStoreController`.
typedef ReviewsEmittedCallback = void Function(
  List<global_review.Review> reviews,
);

enum ReviewMode {
  viewing,
  editing,
}

/// Single source of truth for the plan-review screen. Owns the canonical
/// "live plan" (original + accepted batches), the in-flight edit draft,
/// suggestion batches, comments, section feedback and version history.
class PlanReviewController extends ChangeNotifier {
  PlanReviewController({
    required ExperimentPlan source,
    required ValueChanged<ExperimentPlan> onLivePlanChanged,
    BatchColorPalette? palette,
    String localAuthorId = kLocalAuthorId,
    String conversationId = '',
    String query = '',
    ReviewsEmittedCallback? onReviewsEmitted,
    ChangeTarget? focusedTarget,
    ReviewSection? focusedSection,
    FeedbackPolarity? focusedPolarity,
    bool isReadOnlyFocus = false,
    List<PlanComment> initialComments = const <PlanComment>[],
    Map<ReviewSection, SectionFeedback> initialSectionFeedback =
        const <ReviewSection, SectionFeedback>{},
    List<SuggestionBatch> initialAcceptedBatches =
        const <SuggestionBatch>[],
    List<PlanVersion>? initialVersions,
    String? initialViewingVersionId,
  })  : _original = initialVersions != null && initialVersions.isNotEmpty
            ? deepCopyExperimentPlan(initialVersions.first.snapshot)
            : source,
        _onLivePlanChanged = onLivePlanChanged,
        _palette = palette ?? BatchColorPalette(),
        _localAuthorId = localAuthorId,
        _conversationId = conversationId,
        _query = query,
        _onReviewsEmitted = onReviewsEmitted,
        _focusedTarget = focusedTarget,
        _focusedSection = focusedSection,
        _focusedPolarity = focusedPolarity,
        _isReadOnlyFocus = isReadOnlyFocus {
    if (initialVersions != null && initialVersions.isNotEmpty) {
      for (final PlanVersion v in initialVersions) {
        _versions.add(
          PlanVersion(
            id: v.id,
            snapshot: deepCopyExperimentPlan(v.snapshot),
            batchId: v.batchId,
            authorId: v.authorId,
            at: v.at,
            changeCount: v.changeCount,
          ),
        );
      }
    } else {
      _versions.add(
        PlanVersion(
          id: generateLocalId('ver'),
          snapshot: source,
          batchId: null,
          authorId: _baselineAuthorId,
          at: DateTime.now(),
          changeCount: 0,
        ),
      );
    }
    if (initialComments.isNotEmpty) {
      _comments.addAll(initialComments);
    }
    if (initialSectionFeedback.isNotEmpty) {
      _sectionFeedback.addAll(initialSectionFeedback);
    }
    if (initialAcceptedBatches.isNotEmpty) {
      _acceptedBatches.addAll(initialAcceptedBatches);
    }
    if (initialViewingVersionId != null) {
      final bool known = _versions.any(
        (PlanVersion v) => v.id == initialViewingVersionId,
      );
      _viewingVersionId = known ? initialViewingVersionId : null;
    }
  }

  static const String kLocalAuthorId = 'local-user';
  static const String _baselineAuthorId = 'ai';

  final ValueChanged<ExperimentPlan> _onLivePlanChanged;
  final BatchColorPalette _palette;
  final String _localAuthorId;
  final String _conversationId;
  final String _query;
  final ReviewsEmittedCallback? _onReviewsEmitted;

  final ExperimentPlan _original;
  final List<SuggestionBatch> _acceptedBatches = <SuggestionBatch>[];
  ExperimentPlan? _draft;
  ExperimentPlan? _editBaseline;
  final List<PlanComment> _comments = <PlanComment>[];
  final Map<ReviewSection, SectionFeedback> _sectionFeedback =
      <ReviewSection, SectionFeedback>{};
  final List<PlanVersion> _versions = <PlanVersion>[];

  ReviewMode _mode = ReviewMode.viewing;
  String? _viewingVersionId;

  /// Reviewer-mode focus fields: when set, the read-only widgets render
  /// a one-shot highlight around the matching target/section so the
  /// Reviewer screen can draw attention to a single review.
  final ChangeTarget? _focusedTarget;
  final ReviewSection? _focusedSection;
  final FeedbackPolarity? _focusedPolarity;
  final bool _isReadOnlyFocus;

  ChangeTarget? get focusedTarget => _focusedTarget;
  ReviewSection? get focusedSection => _focusedSection;
  FeedbackPolarity? get focusedPolarity => _focusedPolarity;

  /// True when this controller is rendering a single review in the
  /// Reviewer screen. Editable affordances (action bar, feedback bar,
  /// comment popovers) hide themselves on this signal.
  bool get isReadOnlyFocus => _isReadOnlyFocus;

  ExperimentPlan get original => _original;
  List<SuggestionBatch> get acceptedBatches =>
      List<SuggestionBatch>.unmodifiable(_acceptedBatches);
  ExperimentPlan? get draft => _draft;
  ExperimentPlan? get editBaseline => _editBaseline;
  List<PlanComment> get comments => List<PlanComment>.unmodifiable(_comments);
  Map<ReviewSection, SectionFeedback> get sectionFeedback =>
      Map<ReviewSection, SectionFeedback>.unmodifiable(_sectionFeedback);
  List<PlanVersion> get versions => List<PlanVersion>.unmodifiable(_versions);
  ReviewMode get mode => _mode;
  String? get viewingVersionId => _viewingVersionId;

  /// Whether the user is currently scrubbing through a historical version.
  bool get isHistoricalView => _viewingVersionId != null;

  /// Plan currently displayed in the body. While editing it returns the
  /// draft, while viewing a historical version it returns that snapshot,
  /// otherwise it returns the live plan (original + accepted batches).
  ExperimentPlan get displayPlan {
    if (_mode == ReviewMode.editing && _draft != null) {
      return _draft!;
    }
    if (_viewingVersionId != null) {
      final PlanVersion? version = _versions
          .where((PlanVersion v) => v.id == _viewingVersionId)
          .cast<PlanVersion?>()
          .firstWhere((PlanVersion? v) => v != null, orElse: () => null);
      if (version != null) {
        return version.snapshot;
      }
    }
    return livePlan;
  }

  /// Plan with all accepted batches applied.
  ExperimentPlan get livePlan {
    if (_acceptedBatches.isEmpty) {
      return _original;
    }
    ExperimentPlan plan = _original;
    for (final SuggestionBatch batch in _acceptedBatches) {
      plan = _applyBatch(plan, batch);
    }
    return plan;
  }

  /// Returns the most recent accepted batch that touched [target], if any.
  /// The caller can use [SuggestionBatch.color] to render the field tinted.
  SuggestionBatch? acceptedBatchFor(ChangeTarget target) {
    for (int i = _acceptedBatches.length - 1; i >= 0; i--) {
      final SuggestionBatch batch = _acceptedBatches[i];
      if (batch.changes.any((PlanChange c) => _changeTouches(c, target))) {
        return batch;
      }
    }
    return null;
  }

  /// Returns the color associated with the latest accepted batch that
  /// touched [target], or null if the field is original content.
  Color? colorForTarget(ChangeTarget target) =>
      acceptedBatchFor(target)?.color;

  /// True when at least one accepted batch contains a [FieldChange] for
  /// [target]. Inserts (StepInserted / MaterialInserted) intentionally do
  /// not count: a freshly inserted step/material is communicated by its
  /// parent tile, so a per-field "edited from baseline" highlight would
  /// be redundant.
  bool hasFieldEditFromBaseline(ChangeTarget target) {
    for (final SuggestionBatch batch in _acceptedBatches) {
      for (final PlanChange change in batch.changes) {
        if (change is FieldChange && change.target == target) {
          return true;
        }
      }
    }
    return false;
  }

  /// Formatted v0 baseline value for [target], suitable for display in a
  /// tooltip. Returns `null` when the target was never touched by any
  /// [FieldChange] in an accepted batch (i.e. there is no "previous"
  /// value worth surfacing).
  String? originalLabelFor(ChangeTarget target) {
    if (!hasFieldEditFromBaseline(target)) {
      return null;
    }
    if (target is PlanDescriptionTarget) {
      return _formatStringValue(_original.description);
    }
    if (target is BudgetTotalTarget) {
      return formatBudgetLabel(_original.budget.total);
    }
    if (target is TotalDurationTarget) {
      return formatExperimentPlanTotalDuration(
        _original.timePlan.totalDuration,
      );
    }
    if (target is StepFieldTarget) {
      final Step? step = _findStep(_original, target.stepId);
      if (step == null) return null;
      return _formatStepFieldValue(step, target.field);
    }
    if (target is MaterialFieldTarget) {
      final Material? mat = _findMaterial(_original, target.materialId);
      if (mat == null) return null;
      return _formatMaterialFieldValue(mat, target.field);
    }
    return null;
  }

  String _formatStringValue(String value) {
    return value.isEmpty ? '(empty)' : value;
  }

  String _formatStepFieldValue(Step step, StepField field) {
    switch (field) {
      case StepField.name:
        return _formatStringValue(step.name);
      case StepField.description:
        return _formatStringValue(step.description);
      case StepField.duration:
        return formatDurationLabel(step.duration);
      case StepField.milestone:
        return _formatStringValue(step.milestone ?? '');
    }
  }

  String _formatMaterialFieldValue(Material material, MaterialField field) {
    switch (field) {
      case MaterialField.title:
        return _formatStringValue(material.title);
      case MaterialField.description:
        return _formatStringValue(material.description);
      case MaterialField.catalogNumber:
        return _formatStringValue(material.catalogNumber);
      case MaterialField.amount:
        return material.amount.toString();
      case MaterialField.price:
        return formatBudgetLabel(material.price);
    }
  }

  // --- Mode transitions -----------------------------------------------------

  void enterEditing() {
    if (_mode == ReviewMode.editing) return;
    final ExperimentPlan snapshot = livePlan;
    _draft = snapshot;
    _editBaseline = snapshot;
    _mode = ReviewMode.editing;
    _viewingVersionId = null;
    notifyListeners();
  }

  void cancelEditing() {
    if (_mode != ReviewMode.editing) return;
    _draft = null;
    _editBaseline = null;
    _mode = ReviewMode.viewing;
    notifyListeners();
  }

  /// Diffs the draft against the live plan and commits it as a single
  /// accepted suggestion batch with a fresh palette color. The live plan,
  /// version history, and any [ReviewsEmittedCallback] are updated in
  /// one shot. No-op when nothing has changed.
  void applySuggestions() {
    if (_mode != ReviewMode.editing || _draft == null) return;
    final List<PlanChange> changes =
        diffPlans(before: livePlan, after: _draft!);
    _draft = null;
    _editBaseline = null;
    _mode = ReviewMode.viewing;
    if (changes.isEmpty) {
      notifyListeners();
      return;
    }
    final int batchIndex = _acceptedBatches.length;
    final SuggestionBatch accepted = SuggestionBatch(
      id: generateLocalId('batch'),
      authorId: _localAuthorId,
      createdAt: DateTime.now(),
      color: _palette.colorAt(batchIndex),
      status: BatchStatus.accepted,
      changes: changes,
    );
    _acceptedBatches.add(accepted);
    final ExperimentPlan nextLive = livePlan;
    _versions.add(
      PlanVersion(
        id: generateLocalId('ver'),
        snapshot: nextLive,
        batchId: accepted.id,
        authorId: accepted.authorId,
        at: DateTime.now(),
        changeCount: accepted.changes.length,
      ),
    );
    _reanchorComments(nextLive);
    _emitCorrectionReviews(accepted);
    _onLivePlanChanged(nextLive);
    notifyListeners();
  }

  /// Builds one [global_review.CorrectionReview] per [PlanChange] in
  /// [batch] and forwards them to [_onReviewsEmitted]. Field changes,
  /// step/material insertions and removals are all surfaced.
  void _emitCorrectionReviews(SuggestionBatch batch) {
    final ReviewsEmittedCallback? cb = _onReviewsEmitted;
    if (cb == null) return;
    final List<global_review.Review> emitted = <global_review.Review>[];
    for (final PlanChange change in batch.changes) {
      if (change is FieldChange) {
        emitted.add(
          global_review.CorrectionReview(
            id: generateLocalId('review'),
            conversationId: _conversationId,
            query: _query,
            originalPlan: _original,
            createdAt: DateTime.now(),
            target: change.target,
            before: change.before,
            after: change.after,
          ),
        );
      } else if (change is StepInserted) {
        emitted.add(
          global_review.CorrectionReview(
            id: generateLocalId('review'),
            conversationId: _conversationId,
            query: _query,
            originalPlan: _original,
            createdAt: DateTime.now(),
            target: StepFieldTarget(
              stepId: change.step.id,
              field: StepField.name,
            ),
            before: null,
            after: change.step,
          ),
        );
      } else if (change is StepRemoved) {
        emitted.add(
          global_review.CorrectionReview(
            id: generateLocalId('review'),
            conversationId: _conversationId,
            query: _query,
            originalPlan: _original,
            createdAt: DateTime.now(),
            target: StepFieldTarget(
              stepId: change.step.id,
              field: StepField.name,
            ),
            before: change.step,
            after: null,
          ),
        );
      } else if (change is MaterialInserted) {
        emitted.add(
          global_review.CorrectionReview(
            id: generateLocalId('review'),
            conversationId: _conversationId,
            query: _query,
            originalPlan: _original,
            createdAt: DateTime.now(),
            target: MaterialFieldTarget(
              materialId: change.material.id,
              field: MaterialField.title,
            ),
            before: null,
            after: change.material,
          ),
        );
      } else if (change is MaterialRemoved) {
        emitted.add(
          global_review.CorrectionReview(
            id: generateLocalId('review'),
            conversationId: _conversationId,
            query: _query,
            originalPlan: _original,
            createdAt: DateTime.now(),
            target: MaterialFieldTarget(
              materialId: change.material.id,
              field: MaterialField.title,
            ),
            before: change.material,
            after: null,
          ),
        );
      }
    }
    if (emitted.isEmpty) return;
    cb(emitted);
  }

  // --- Section feedback -----------------------------------------------------

  void setSectionFeedback(ReviewSection section, FeedbackPolarity polarity) {
    final SectionFeedback? current = _sectionFeedback[section];
    final bool isToggleOff = current?.polarity == polarity;
    if (isToggleOff) {
      _sectionFeedback.remove(section);
    } else {
      _sectionFeedback[section] = SectionFeedback(
        polarity: polarity,
        authorId: _localAuthorId,
        at: DateTime.now(),
      );
    }
    notifyListeners();
    if (!isToggleOff) {
      _emitFeedbackReview(section, polarity);
    }
  }

  void _emitFeedbackReview(
    ReviewSection section,
    FeedbackPolarity polarity,
  ) {
    final ReviewsEmittedCallback? cb = _onReviewsEmitted;
    if (cb == null) return;
    cb(<global_review.Review>[
      global_review.FeedbackReview(
        id: generateLocalId('review'),
        conversationId: _conversationId,
        query: _query,
        originalPlan: _original,
        createdAt: DateTime.now(),
        section: section,
        polarity: polarity,
      ),
    ]);
  }

  // --- Comments -------------------------------------------------------------

  PlanComment addComment({
    required ChangeTarget target,
    required String quote,
    required int start,
    required int end,
    required String body,
  }) {
    final PlanComment comment = PlanComment(
      id: generateLocalId('comment'),
      authorId: _localAuthorId,
      createdAt: DateTime.now(),
      anchor: CommentAnchor(
        target: target,
        quote: quote,
        start: start,
        end: end,
      ),
      body: body,
    );
    _comments.add(comment);
    notifyListeners();
    _emitCommentReview(comment);
    return comment;
  }

  void _emitCommentReview(PlanComment comment) {
    final ReviewsEmittedCallback? cb = _onReviewsEmitted;
    if (cb == null) return;
    cb(<global_review.Review>[
      global_review.CommentReview(
        id: generateLocalId('review'),
        conversationId: _conversationId,
        query: _query,
        originalPlan: _original,
        createdAt: comment.createdAt,
        target: comment.anchor.target,
        quote: comment.anchor.quote,
        start: comment.anchor.start,
        end: comment.anchor.end,
        body: comment.body,
      ),
    ]);
  }

  void updateComment(String commentId, String body) {
    final int index =
        _comments.indexWhere((PlanComment c) => c.id == commentId);
    if (index < 0) return;
    _comments[index] = _comments[index].copyWith(body: body);
    notifyListeners();
  }

  void removeComment(String commentId) {
    _comments.removeWhere((PlanComment c) => c.id == commentId);
    notifyListeners();
  }

  /// Returns comments whose anchor still matches the given current text.
  List<PlanComment> commentsForTarget(
    ChangeTarget target,
    String currentText,
  ) {
    final List<PlanComment> matched = <PlanComment>[];
    for (final PlanComment c in _comments) {
      if (c.anchor.target != target) continue;
      if (c.anchor.start <= currentText.length &&
          c.anchor.end <= currentText.length &&
          currentText.substring(c.anchor.start, c.anchor.end) ==
              c.anchor.quote) {
        matched.add(c);
        continue;
      }
      final int rel = currentText.indexOf(c.anchor.quote);
      if (rel >= 0) {
        matched.add(c.copyWith(
          anchor: c.anchor.copyWith(start: rel, end: rel + c.anchor.quote.length),
        ));
      }
    }
    return matched;
  }

  /// Comments that no longer have a matching anchor in the live plan.
  List<PlanComment> get staleComments {
    final ExperimentPlan plan = livePlan;
    return _comments
        .where((PlanComment c) => !_isAnchorAlive(c.anchor, plan))
        .toList(growable: false);
  }

  // --- History --------------------------------------------------------------

  void viewVersion(String versionId) {
    if (_mode == ReviewMode.editing) return;
    if (!_versions.any((PlanVersion v) => v.id == versionId)) return;
    _viewingVersionId = versionId;
    notifyListeners();
  }

  void returnToCurrentVersion() {
    if (_viewingVersionId == null) return;
    _viewingVersionId = null;
    notifyListeners();
  }

  /// Reverts the live plan to the snapshot stored in [versionId] by
  /// committing the inverse diff as a fresh accepted batch. Keeps the
  /// version list strictly forward-only so the user can always navigate
  /// back to any previous state via the history drawer. No-op when the
  /// requested version already matches the live plan, when the user is
  /// editing, or when the id is unknown.
  void restoreVersion(String versionId) {
    if (_mode == ReviewMode.editing) return;
    final int idx = _versions.indexWhere((PlanVersion v) => v.id == versionId);
    if (idx < 0) return;
    final ExperimentPlan target = _versions[idx].snapshot;
    final List<PlanChange> changes =
        diffPlans(before: livePlan, after: target);
    if (changes.isEmpty) {
      _viewingVersionId = null;
      notifyListeners();
      return;
    }
    final int batchIndex = _acceptedBatches.length;
    final SuggestionBatch restored = SuggestionBatch(
      id: generateLocalId('batch'),
      authorId: _localAuthorId,
      createdAt: DateTime.now(),
      color: _palette.colorAt(batchIndex),
      status: BatchStatus.accepted,
      changes: changes,
    );
    _acceptedBatches.add(restored);
    final ExperimentPlan nextLive = livePlan;
    _versions.add(
      PlanVersion(
        id: generateLocalId('ver'),
        snapshot: nextLive,
        batchId: restored.id,
        authorId: restored.authorId,
        at: DateTime.now(),
        changeCount: restored.changes.length,
      ),
    );
    _viewingVersionId = null;
    _reanchorComments(nextLive);
    _emitCorrectionReviews(restored);
    _onLivePlanChanged(nextLive);
    notifyListeners();
  }

  /// Accepted batch that introduced the version currently being viewed
  /// (null when not in historical view, or when viewing the v0 baseline).
  SuggestionBatch? get _viewedVersionBatch {
    final String? id = _viewingVersionId;
    if (id == null) return null;
    final int idx = _versions.indexWhere((PlanVersion v) => v.id == id);
    if (idx < 0) return null;
    final String? batchId = _versions[idx].batchId;
    if (batchId == null) return null;
    for (final SuggestionBatch b in _acceptedBatches) {
      if (b.id == batchId) return b;
    }
    return null;
  }

  /// Snapshot of the version immediately preceding the one being viewed
  /// (null on the v0 baseline or outside historical view). Used as the
  /// "before" reference when surfacing per-revision originals.
  ExperimentPlan? get _previousVersionSnapshot {
    final String? id = _viewingVersionId;
    if (id == null) return null;
    final int idx = _versions.indexWhere((PlanVersion v) => v.id == id);
    if (idx <= 0) return null;
    return _versions[idx - 1].snapshot;
  }

  /// Color to tint [target] with in the body. In historical view, only
  /// fields touched by the viewed revision's batch get the highlight, so
  /// the user sees exactly what changed in that revision. Otherwise this
  /// delegates to the cumulative [colorForTarget].
  Color? effectiveColorForTarget(ChangeTarget target) {
    if (!isHistoricalView) return colorForTarget(target);
    final SuggestionBatch? batch = _viewedVersionBatch;
    if (batch == null) return null;
    final bool touches =
        batch.changes.any((PlanChange c) => _changeTouches(c, target));
    return touches ? batch.color : null;
  }

  /// True when [target] received a [FieldChange] in the relevant scope:
  /// the viewed revision in historical view, the cumulative baseline diff
  /// otherwise. Drives the inline "original value" caret.
  bool effectiveHasFieldEdit(ChangeTarget target) {
    if (!isHistoricalView) return hasFieldEditFromBaseline(target);
    final SuggestionBatch? batch = _viewedVersionBatch;
    if (batch == null) return false;
    return batch.changes
        .any((PlanChange c) => c is FieldChange && c.target == target);
  }

  /// Drives [buildSuggestionAwareSpan] (bold + background). True for v0
  /// field edits and for every field of a step or material that does not
  /// appear in the original plan.
  bool shouldHighlightFieldContent(ChangeTarget target) {
    final Color? c = effectiveColorForTarget(target);
    if (c == null) {
      return false;
    }
    if (target is StepFieldTarget) {
      final bool isNew = !_original.timePlan.steps
          .any((Step s) => s.id == target.stepId);
      if (isNew) {
        return true;
      }
      return effectiveHasFieldEdit(target);
    }
    if (target is MaterialFieldTarget) {
      final bool isNew = !_original.budget.materials
          .any((Material m) => m.id == target.materialId);
      if (isNew) {
        return true;
      }
      return effectiveHasFieldEdit(target);
    }
    return effectiveHasFieldEdit(target);
  }

  /// Blends a tinted read-only step row when the step is new to the
  /// baseline or has field edits. Otherwise returns null.
  Color? reviewContainerAccentForStep(String stepId) {
    if (!_original.timePlan.steps.any((Step s) => s.id == stepId)) {
      return effectiveColorForTarget(
        StepFieldTarget(stepId: stepId, field: StepField.name),
      );
    }
    for (final StepField field in StepField.values) {
      final StepFieldTarget t = StepFieldTarget(
        stepId: stepId,
        field: field,
      );
      if (effectiveHasFieldEdit(t)) {
        return effectiveColorForTarget(t);
      }
    }
    return null;
  }

  /// Blends a tinted read-only material row when the material is new to the
  /// baseline or has field edits. Otherwise returns null.
  Color? reviewContainerAccentForMaterial(String materialId) {
    if (!_original.budget.materials
        .any((Material m) => m.id == materialId)) {
      return effectiveColorForTarget(
        MaterialFieldTarget(
          materialId: materialId,
          field: MaterialField.title,
        ),
      );
    }
    for (final MaterialField field in MaterialField.values) {
      final MaterialFieldTarget t = MaterialFieldTarget(
        materialId: materialId,
        field: field,
      );
      if (effectiveHasFieldEdit(t)) {
        return effectiveColorForTarget(t);
      }
    }
    return null;
  }

  /// Label shown in the "original" tooltip for [target]. In historical
  /// view it reads from the previous version's snapshot so the tooltip
  /// reflects the value as it was before this revision; otherwise it
  /// delegates to [originalLabelFor] (v0 baseline).
  String? effectiveOriginalLabelFor(ChangeTarget target) {
    if (!isHistoricalView) return originalLabelFor(target);
    if (!effectiveHasFieldEdit(target)) return null;
    final ExperimentPlan? prev = _previousVersionSnapshot;
    if (prev == null) return null;
    return _formatTargetValue(target, prev);
  }

  String? _formatTargetValue(ChangeTarget target, ExperimentPlan plan) {
    if (target is PlanDescriptionTarget) {
      return _formatStringValue(plan.description);
    }
    if (target is BudgetTotalTarget) {
      return formatBudgetLabel(plan.budget.total);
    }
    if (target is TotalDurationTarget) {
      return formatExperimentPlanTotalDuration(plan.timePlan.totalDuration);
    }
    if (target is StepFieldTarget) {
      final Step? step = _findStep(plan, target.stepId);
      if (step == null) return null;
      return _formatStepFieldValue(step, target.field);
    }
    if (target is MaterialFieldTarget) {
      final Material? mat = _findMaterial(plan, target.materialId);
      if (mat == null) return null;
      return _formatMaterialFieldValue(mat, target.field);
    }
    return null;
  }

  String authorLabel(String authorId) {
    if (authorId == _localAuthorId) return 'You';
    if (authorId == _baselineAuthorId) return 'Marie';
    return authorId;
  }

  static const String _kLocalUserAvatarUrl = 'https://i.pravatar.cc/120?u=jane-doe';
  static const String _kMarieAvatarUrl = 'https://i.pravatar.cc/120?u=marie-lab';

  /// Shown in comment UI (e.g. next to an avatar) — matches the sidebar name for the
  /// local user.
  String authorDisplayName(String authorId) {
    if (authorId == _localAuthorId) return 'Jane Doe';
    if (authorId == _baselineAuthorId) return 'Marie';
    return authorId;
  }

  String authorAvatarUrl(String authorId) {
    if (authorId == _localAuthorId) return _kLocalUserAvatarUrl;
    if (authorId == _baselineAuthorId) return _kMarieAvatarUrl;
    return 'https://i.pravatar.cc/120?u=${Uri.encodeComponent(authorId)}';
  }

  // --- Editing helpers (operate on _draft) ---------------------------------

  void updateTotalDuration(Duration value) {
    final ExperimentPlan? draft = _draft;
    if (draft == null) return;
    if (value.isNegative || value == draft.timePlan.totalDuration) return;
    _draft = draft.copyWith(
      timePlan: draft.timePlan.copyWith(totalDuration: value),
    );
    notifyListeners();
  }

  void updateBudgetTotal(double value) {
    final ExperimentPlan? draft = _draft;
    if (draft == null) return;
    if (value < 0 || value == draft.budget.total) return;
    _draft = draft.copyWith(
      budget: draft.budget.copyWith(total: value),
    );
    notifyListeners();
  }

  void updateStep(int index, Step step) {
    final ExperimentPlan? draft = _draft;
    if (draft == null) return;
    if (index < 0 || index >= draft.timePlan.steps.length) return;
    final List<Step> next = List<Step>.from(draft.timePlan.steps);
    next[index] = step.copyWith(number: index + 1);
    _draft = draft.copyWith(
      timePlan: draft.timePlan.copyWith(steps: next),
    );
    notifyListeners();
  }

  void insertStepAt(int afterIndex) {
    final ExperimentPlan? draft = _draft;
    if (draft == null) return;
    final List<Step> current = draft.timePlan.steps;
    final int insertIndex = (afterIndex + 1).clamp(0, current.length);
    final Step blank = Step.blank(number: insertIndex + 1);
    final List<Step> next = List<Step>.from(current)
      ..insert(insertIndex, blank);
    _draft = draft.copyWith(
      timePlan: draft.timePlan.copyWith(steps: _renumberSteps(next)),
    );
    notifyListeners();
  }

  void appendStep() {
    final ExperimentPlan? draft = _draft;
    if (draft == null) return;
    final List<Step> next = List<Step>.from(draft.timePlan.steps)
      ..add(Step.blank(number: draft.timePlan.steps.length + 1));
    _draft = draft.copyWith(
      timePlan: draft.timePlan.copyWith(steps: next),
    );
    notifyListeners();
  }

  void removeStep(int index) {
    final ExperimentPlan? draft = _draft;
    if (draft == null) return;
    final List<Step> current = draft.timePlan.steps;
    if (index < 0 || index >= current.length) return;
    final List<Step> next = List<Step>.from(current)..removeAt(index);
    _draft = draft.copyWith(
      timePlan: draft.timePlan.copyWith(steps: _renumberSteps(next)),
    );
    notifyListeners();
  }

  void updateMaterial(int index, Material material) {
    final ExperimentPlan? draft = _draft;
    if (draft == null) return;
    if (index < 0 || index >= draft.budget.materials.length) return;
    final List<Material> next =
        List<Material>.from(draft.budget.materials);
    next[index] = material;
    _draft = draft.copyWith(
      budget: draft.budget.copyWith(materials: next),
    );
    notifyListeners();
  }

  void appendMaterial() {
    final ExperimentPlan? draft = _draft;
    if (draft == null) return;
    final List<Material> next =
        List<Material>.from(draft.budget.materials)..add(Material.blank());
    _draft = draft.copyWith(
      budget: draft.budget.copyWith(materials: next),
    );
    notifyListeners();
  }

  void removeMaterial(int index) {
    final ExperimentPlan? draft = _draft;
    if (draft == null) return;
    final List<Material> current = draft.budget.materials;
    if (index < 0 || index >= current.length) return;
    final List<Material> next = List<Material>.from(current)..removeAt(index);
    _draft = draft.copyWith(
      budget: draft.budget.copyWith(materials: next),
    );
    notifyListeners();
  }

  // --- Draft diff helpers (edit-mode highlights) ---------------------------

  /// True when the step with [stepId] does not exist in the edit baseline
  /// (i.e. the user added it during the current edit session).
  bool isStepInsertedInDraft(String stepId) {
    final ExperimentPlan? base = _editBaseline;
    if (base == null) return false;
    return !base.timePlan.steps.any((Step s) => s.id == stepId);
  }

  bool isMaterialInsertedInDraft(String materialId) {
    final ExperimentPlan? base = _editBaseline;
    if (base == null) return false;
    return !base.budget.materials.any((Material m) => m.id == materialId);
  }

  /// Set of fields on [stepId] that differ between the baseline and the
  /// current draft. Empty for inserted or unchanged steps.
  Set<StepField> draftChangedStepFields(String stepId) {
    final ExperimentPlan? base = _editBaseline;
    final ExperimentPlan? draft = _draft;
    if (base == null || draft == null) return const <StepField>{};
    final Step? before = _findStep(base, stepId);
    final Step? after = _findStep(draft, stepId);
    if (before == null || after == null) return const <StepField>{};
    final Set<StepField> changed = <StepField>{};
    if (before.name != after.name) changed.add(StepField.name);
    if (before.description != after.description) {
      changed.add(StepField.description);
    }
    if (before.duration != after.duration) changed.add(StepField.duration);
    if (before.milestone != after.milestone) changed.add(StepField.milestone);
    return changed;
  }

  Set<MaterialField> draftChangedMaterialFields(String materialId) {
    final ExperimentPlan? base = _editBaseline;
    final ExperimentPlan? draft = _draft;
    if (base == null || draft == null) return const <MaterialField>{};
    final Material? before = _findMaterial(base, materialId);
    final Material? after = _findMaterial(draft, materialId);
    if (before == null || after == null) return const <MaterialField>{};
    final Set<MaterialField> changed = <MaterialField>{};
    if (before.title != after.title) changed.add(MaterialField.title);
    if (before.catalogNumber != after.catalogNumber) {
      changed.add(MaterialField.catalogNumber);
    }
    if (before.description != after.description) {
      changed.add(MaterialField.description);
    }
    if (before.amount != after.amount) changed.add(MaterialField.amount);
    if (before.price != after.price) changed.add(MaterialField.price);
    return changed;
  }

  /// True when the plan-level scalar at [target] has been edited in the
  /// current draft. Only meaningful for [PlanDescriptionTarget],
  /// [BudgetTotalTarget] and [TotalDurationTarget].
  bool isDraftFieldChanged(ChangeTarget target) {
    final ExperimentPlan? base = _editBaseline;
    final ExperimentPlan? draft = _draft;
    if (base == null || draft == null) return false;
    if (target is PlanDescriptionTarget) {
      return base.description != draft.description;
    }
    if (target is BudgetTotalTarget) {
      return base.budget.total != draft.budget.total;
    }
    if (target is TotalDurationTarget) {
      return base.timePlan.totalDuration != draft.timePlan.totalDuration;
    }
    return false;
  }

  /// All steps removed from the draft, anchored to the surviving step they
  /// previously followed in the baseline so the UI can render tombstones
  /// in the right slot. Order matches the baseline order.
  List<RemovedStepSlot> get draftRemovedStepSlots {
    final ExperimentPlan? base = _editBaseline;
    final ExperimentPlan? draft = _draft;
    if (base == null || draft == null) return const <RemovedStepSlot>[];
    final Set<String> draftIds = <String>{
      for (final Step s in draft.timePlan.steps) s.id,
    };
    final List<RemovedStepSlot> slots = <RemovedStepSlot>[];
    String? lastSurvivingId;
    for (int i = 0; i < base.timePlan.steps.length; i++) {
      final Step current = base.timePlan.steps[i];
      if (draftIds.contains(current.id)) {
        lastSurvivingId = current.id;
        continue;
      }
      slots.add(RemovedStepSlot(
        step: current,
        baselineIndex: i,
        afterDraftStepId: lastSurvivingId,
      ));
    }
    return slots;
  }

  List<RemovedMaterialSlot> get draftRemovedMaterialSlots {
    final ExperimentPlan? base = _editBaseline;
    final ExperimentPlan? draft = _draft;
    if (base == null || draft == null) return const <RemovedMaterialSlot>[];
    final Set<String> draftIds = <String>{
      for (final Material m in draft.budget.materials) m.id,
    };
    final List<RemovedMaterialSlot> slots = <RemovedMaterialSlot>[];
    String? lastSurvivingId;
    for (int i = 0; i < base.budget.materials.length; i++) {
      final Material current = base.budget.materials[i];
      if (draftIds.contains(current.id)) {
        lastSurvivingId = current.id;
        continue;
      }
      slots.add(RemovedMaterialSlot(
        material: current,
        baselineIndex: i,
        afterDraftMaterialId: lastSurvivingId,
      ));
    }
    return slots;
  }

  Step? _findStep(ExperimentPlan plan, String id) {
    for (final Step s in plan.timePlan.steps) {
      if (s.id == id) return s;
    }
    return null;
  }

  Material? _findMaterial(ExperimentPlan plan, String id) {
    for (final Material m in plan.budget.materials) {
      if (m.id == id) return m;
    }
    return null;
  }

  // --- Internals ------------------------------------------------------------

  List<Step> _renumberSteps(List<Step> steps) {
    final List<Step> next = <Step>[];
    for (int i = 0; i < steps.length; i++) {
      next.add(steps[i].copyWith(number: i + 1));
    }
    return next;
  }

  bool _changeTouches(PlanChange change, ChangeTarget target) {
    if (change is FieldChange) {
      return change.target == target;
    }
    if (change is StepInserted && target is StepFieldTarget) {
      return change.step.id == target.stepId;
    }
    if (change is MaterialInserted && target is MaterialFieldTarget) {
      return change.material.id == target.materialId;
    }
    return false;
  }

  ExperimentPlan _applyBatch(ExperimentPlan plan, SuggestionBatch batch) {
    ExperimentPlan next = plan;
    for (final PlanChange change in batch.changes) {
      next = _applyChange(next, change);
    }
    return next;
  }

  ExperimentPlan _applyChange(ExperimentPlan plan, PlanChange change) {
    if (change is FieldChange) {
      return _applyFieldChange(plan, change);
    }
    if (change is StepInserted) {
      final List<Step> steps = List<Step>.from(plan.timePlan.steps);
      final int idx = change.index.clamp(0, steps.length);
      steps.insert(idx, change.step);
      return plan.copyWith(
        timePlan: plan.timePlan.copyWith(steps: _renumberSteps(steps)),
      );
    }
    if (change is StepRemoved) {
      final List<Step> steps = plan.timePlan.steps
          .where((Step s) => s.id != change.step.id)
          .toList();
      return plan.copyWith(
        timePlan: plan.timePlan.copyWith(steps: _renumberSteps(steps)),
      );
    }
    if (change is MaterialInserted) {
      final List<Material> mats =
          List<Material>.from(plan.budget.materials);
      final int idx = change.index.clamp(0, mats.length);
      mats.insert(idx, change.material);
      return plan.copyWith(budget: plan.budget.copyWith(materials: mats));
    }
    if (change is MaterialRemoved) {
      final List<Material> mats = plan.budget.materials
          .where((Material m) => m.id != change.material.id)
          .toList();
      return plan.copyWith(budget: plan.budget.copyWith(materials: mats));
    }
    return plan;
  }

  ExperimentPlan _applyFieldChange(ExperimentPlan plan, FieldChange change) {
    final ChangeTarget target = change.target;
    if (target is PlanDescriptionTarget) {
      return plan.copyWith(description: change.after as String);
    }
    if (target is BudgetTotalTarget) {
      return plan.copyWith(
        budget: plan.budget.copyWith(total: change.after as double),
      );
    }
    if (target is TotalDurationTarget) {
      return plan.copyWith(
        timePlan: plan.timePlan.copyWith(
          totalDuration: change.after as Duration,
        ),
      );
    }
    if (target is StepFieldTarget) {
      final List<Step> steps = List<Step>.from(plan.timePlan.steps);
      final int idx =
          steps.indexWhere((Step s) => s.id == target.stepId);
      if (idx < 0) return plan;
      steps[idx] = _stepWithFieldUpdated(steps[idx], target, change.after);
      return plan.copyWith(
        timePlan: plan.timePlan.copyWith(steps: steps),
      );
    }
    if (target is MaterialFieldTarget) {
      final List<Material> mats =
          List<Material>.from(plan.budget.materials);
      final int idx =
          mats.indexWhere((Material m) => m.id == target.materialId);
      if (idx < 0) return plan;
      mats[idx] = _materialWithFieldUpdated(mats[idx], target, change.after);
      return plan.copyWith(budget: plan.budget.copyWith(materials: mats));
    }
    return plan;
  }

  Step _stepWithFieldUpdated(Step step, StepFieldTarget target, Object? value) {
    switch (target.field) {
      case StepField.name:
        return step.copyWith(name: value as String);
      case StepField.description:
        return step.copyWith(description: value as String);
      case StepField.duration:
        return step.copyWith(duration: value as Duration);
      case StepField.milestone:
        if (value == null) {
          return step.copyWith(clearMilestone: true);
        }
        return step.copyWith(milestone: value as String);
    }
  }

  Material _materialWithFieldUpdated(
    Material material,
    MaterialFieldTarget target,
    Object? value,
  ) {
    switch (target.field) {
      case MaterialField.title:
        return material.copyWith(title: value as String);
      case MaterialField.catalogNumber:
        return material.copyWith(catalogNumber: value as String);
      case MaterialField.description:
        return material.copyWith(description: value as String);
      case MaterialField.amount:
        return material.copyWith(amount: value as int);
      case MaterialField.price:
        return material.copyWith(price: value as double);
    }
  }

  void _reanchorComments(ExperimentPlan plan) {
    for (int i = 0; i < _comments.length; i++) {
      final PlanComment c = _comments[i];
      if (_isAnchorAlive(c.anchor, plan)) continue;
      final String? currentText = _readTargetText(c.anchor.target, plan);
      if (currentText == null) continue;
      final int rel = currentText.indexOf(c.anchor.quote);
      if (rel < 0) continue;
      _comments[i] = c.copyWith(
        anchor: c.anchor.copyWith(
          start: rel,
          end: rel + c.anchor.quote.length,
        ),
      );
    }
  }

  bool _isAnchorAlive(CommentAnchor anchor, ExperimentPlan plan) {
    final String? text = _readTargetText(anchor.target, plan);
    if (text == null) return false;
    if (anchor.start < 0 || anchor.end > text.length) return false;
    return text.substring(anchor.start, anchor.end) == anchor.quote;
  }

  String? _readTargetText(ChangeTarget target, ExperimentPlan plan) {
    if (target is PlanDescriptionTarget) {
      return plan.description;
    }
    if (target is StepFieldTarget) {
      final Step? step = plan.timePlan.steps
          .where((Step s) => s.id == target.stepId)
          .cast<Step?>()
          .firstWhere((Step? s) => s != null, orElse: () => null);
      if (step == null) return null;
      return _stepFieldText(step, target.field);
    }
    if (target is MaterialFieldTarget) {
      final Material? mat = plan.budget.materials
          .where((Material m) => m.id == target.materialId)
          .cast<Material?>()
          .firstWhere((Material? m) => m != null, orElse: () => null);
      if (mat == null) return null;
      return _materialFieldText(mat, target.field);
    }
    return null;
  }

  String _stepFieldText(Step step, StepField field) {
    switch (field) {
      case StepField.name:
        return step.name;
      case StepField.description:
        return step.description;
      case StepField.milestone:
        return step.milestone ?? '';
      case StepField.duration:
        return '';
    }
  }

  String _materialFieldText(Material material, MaterialField field) {
    switch (field) {
      case MaterialField.title:
        return material.title;
      case MaterialField.description:
        return material.description;
      case MaterialField.catalogNumber:
        return material.catalogNumber;
      case MaterialField.amount:
      case MaterialField.price:
        return '';
    }
  }
}
