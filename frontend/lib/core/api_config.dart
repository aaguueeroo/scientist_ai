/// Compile-time API base URL, e.g.
/// `--dart-define=SCIENTIST_API_BASE_URL=http://127.0.0.1:8000`
const String kScientistApiBaseUrl = String.fromEnvironment(
  'SCIENTIST_API_BASE_URL',
  defaultValue: '',
);

bool get kUseRealScientistApi => kScientistApiBaseUrl.trim().isNotEmpty;
