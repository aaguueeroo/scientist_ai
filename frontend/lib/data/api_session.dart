/// In-memory `plan_id` from the last successful `POST /experiment-plan` so
/// `POST /feedback` can reference it. Cleared on app restart; replace with
/// real persistence when a plan store is wired in the UI.
class ApiSession {
  ApiSession._();

  static String? lastServerPlanId;
}
