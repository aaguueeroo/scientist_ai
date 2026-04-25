import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;

import '../../../core/id_generator.dart';
import '../../../models/experiment_plan.dart';
import 'models/batch_status.dart';
import 'models/change_target.dart';
import 'models/comment_anchor.dart';
import 'models/feedback_polarity.dart';
import 'models/material_field.dart';
import 'models/plan_change.dart';
import 'models/plan_comment.dart';
import 'models/plan_version.dart';
import 'models/review_section.dart';
import 'models/section_feedback.dart';
import 'models/step_field.dart';
import 'models/suggestion_batch.dart';
import 'plan_diff.dart';
import 'review_color_palette.dart';

enum ReviewMode {
  viewing,
  editing,
  reviewingPending,
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
  })  : _original = source,
        _onLivePlanChanged = onLivePlanChanged,
        _palette = palette ?? BatchColorPalette(),
        _localAuthorId = localAuthorId {
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

  static const String kLocalAuthorId = 'local-user';
  static const String _baselineAuthorId = 'ai';

  final ValueChanged<ExperimentPlan> _onLivePlanChanged;
  final BatchColorPalette _palette;
  final String _localAuthorId;

  final ExperimentPlan _original;
  final List<SuggestionBatch> _acceptedBatches = <SuggestionBatch>[];
  SuggestionBatch? _pendingBatch;
  ExperimentPlan? _draft;
  final List<PlanComment> _comments = <PlanComment>[];
  final Map<ReviewSection, SectionFeedback> _sectionFeedback =
      <ReviewSection, SectionFeedback>{};
  final List<PlanVersion> _versions = <PlanVersion>[];

  ReviewMode _mode = ReviewMode.viewing;
  String? _viewingVersionId;

  ExperimentPlan get original => _original;
  List<SuggestionBatch> get acceptedBatches =>
      List<SuggestionBatch>.unmodifiable(_acceptedBatches);
  SuggestionBatch? get pendingBatch => _pendingBatch;
  ExperimentPlan? get draft => _draft;
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

  /// Plan with all accepted batches applied. Pending batches do NOT count;
  /// they only modify the rendering layer.
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

  /// Returns the pending [FieldChange] for [target] if any. Used by
  /// SuggestionAwareText to render the strikethrough+colored layout.
  FieldChange? pendingFieldChangeFor(ChangeTarget target) {
    final SuggestionBatch? pending = _pendingBatch;
    if (pending == null) {
      return null;
    }
    for (final PlanChange change in pending.changes) {
      if (change is FieldChange && change.target == target) {
        return change;
      }
    }
    return null;
  }

  /// Returns true when [stepId] was inserted by the pending batch.
  bool isStepPendingInsert(String stepId) {
    final SuggestionBatch? pending = _pendingBatch;
    if (pending == null) return false;
    return pending.changes.any(
      (PlanChange c) => c is StepInserted && c.step.id == stepId,
    );
  }

  /// Returns the [StepRemoved] entry for the pending batch if any.
  StepRemoved? pendingStepRemovalFor(String stepId) {
    final SuggestionBatch? pending = _pendingBatch;
    if (pending == null) return null;
    for (final PlanChange c in pending.changes) {
      if (c is StepRemoved && c.step.id == stepId) {
        return c;
      }
    }
    return null;
  }

  bool isMaterialPendingInsert(String materialId) {
    final SuggestionBatch? pending = _pendingBatch;
    if (pending == null) return false;
    return pending.changes.any(
      (PlanChange c) => c is MaterialInserted && c.material.id == materialId,
    );
  }

  MaterialRemoved? pendingMaterialRemovalFor(String materialId) {
    final SuggestionBatch? pending = _pendingBatch;
    if (pending == null) return null;
    for (final PlanChange c in pending.changes) {
      if (c is MaterialRemoved && c.material.id == materialId) {
        return c;
      }
    }
    return null;
  }

  /// Returns the color associated with the latest accepted batch that
  /// touched [target], or null if the field is original content.
  Color? colorForTarget(ChangeTarget target) =>
      acceptedBatchFor(target)?.color;

  // --- Mode transitions -----------------------------------------------------

  void enterEditing() {
    if (_mode == ReviewMode.editing) return;
    _draft = livePlan;
    _mode = ReviewMode.editing;
    _viewingVersionId = null;
    notifyListeners();
  }

  void cancelEditing() {
    if (_mode != ReviewMode.editing) return;
    _draft = null;
    _mode = ReviewMode.viewing;
    notifyListeners();
  }

  /// Diffs the draft against the live plan and turns it into a pending
  /// batch. No-op when nothing changed.
  void applySuggestions() {
    if (_mode != ReviewMode.editing || _draft == null) return;
    final List<PlanChange> changes =
        diffPlans(before: livePlan, after: _draft!);
    if (changes.isEmpty) {
      _draft = null;
      _mode = ReviewMode.viewing;
      notifyListeners();
      return;
    }
    final int batchIndex = _acceptedBatches.length;
    _pendingBatch = SuggestionBatch(
      id: generateLocalId('batch'),
      authorId: _localAuthorId,
      createdAt: DateTime.now(),
      color: _palette.colorAt(batchIndex),
      status: BatchStatus.pending,
      changes: changes,
    );
    _draft = null;
    _mode = ReviewMode.reviewingPending;
    notifyListeners();
  }

  /// Promote the pending batch to accepted, push a new version, and tell
  /// the parent controller about the new live plan.
  void acceptPendingBatch() {
    final SuggestionBatch? pending = _pendingBatch;
    if (pending == null) return;
    final SuggestionBatch accepted = pending.copyWith(
      status: BatchStatus.accepted,
    );
    _acceptedBatches.add(accepted);
    _pendingBatch = null;
    _mode = ReviewMode.viewing;
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
    _onLivePlanChanged(nextLive);
    notifyListeners();
  }

  void discardPendingBatch() {
    if (_pendingBatch == null) return;
    _pendingBatch = null;
    _mode = ReviewMode.viewing;
    notifyListeners();
  }

  // --- Section feedback -----------------------------------------------------

  void setSectionFeedback(ReviewSection section, FeedbackPolarity polarity) {
    final SectionFeedback? current = _sectionFeedback[section];
    if (current?.polarity == polarity) {
      _sectionFeedback.remove(section);
    } else {
      _sectionFeedback[section] = SectionFeedback(
        polarity: polarity,
        authorId: _localAuthorId,
        at: DateTime.now(),
      );
    }
    notifyListeners();
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
    return comment;
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
    if (_mode == ReviewMode.editing || _mode == ReviewMode.reviewingPending) {
      return;
    }
    if (!_versions.any((PlanVersion v) => v.id == versionId)) return;
    _viewingVersionId = versionId;
    notifyListeners();
  }

  void returnToCurrentVersion() {
    if (_viewingVersionId == null) return;
    _viewingVersionId = null;
    notifyListeners();
  }

  String authorLabel(String authorId) {
    if (authorId == _localAuthorId) return 'You';
    if (authorId == _baselineAuthorId) return 'AI';
    return authorId;
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
