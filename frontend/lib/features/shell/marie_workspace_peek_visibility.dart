import '../../controllers/scientist_controller.dart';

/// Literature tab / pane: show peek when a review snapshot exists and loading
/// has finished.
bool mariePeekShowLiteratureBody(ScientistController c) {
  if (c.literatureReview == null || c.isLoadingLiterature) {
    return false;
  }
  return true;
}

/// Plan tab on main workspace: plan, error, or QC response (not spinner, not
/// empty CTA).
bool mariePeekShowPlanBody(ScientistController c) {
  if (c.isLoadingLiterature || c.literatureReview == null) {
    return false;
  }
  if (c.isLoadingPlan && c.experimentPlan == null) {
    return false;
  }
  if (c.experimentPlan == null &&
      c.planError == null &&
      c.planFetchQc == null) {
    return false;
  }
  return true;
}

/// Past conversation: literature (step 1) or plan review (step 2) only.
bool mariePeekShowPastConversation(ScientistController c, int stepIndex) {
  if (stepIndex == 1) {
    return mariePeekShowLiteratureBody(c);
  }
  if (stepIndex == 2) {
    if (c.isLoadingLiterature || c.literatureReview == null) {
      return false;
    }
    if (c.isLoadingPlan && c.experimentPlan == null) {
      return false;
    }
    return c.experimentPlan != null;
  }
  return false;
}
