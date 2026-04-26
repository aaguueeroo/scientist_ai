/// Base URL of the AI Scientist FastAPI app (no trailing slash), e.g.
/// `http://localhost:8000` or, on the Android emulator, `http://10.0.2.2:8000`.
///
/// **Compile-time override** (replaces the default for release/profile builds):
/// `flutter run -d chrome --dart-define=SCIENTIST_API_BASE_URL=http://127.0.0.1:8000`
///
/// **Offline / mock** [MockScientistBackendClient]: set the base URL to empty at
/// compile time, e.g. `flutter run --dart-define=SCIENTIST_API_BASE_URL=`
/// (empty value ⇒ [kUseRealScientistApi] is false).
const String kScientistApiBaseUrl = String.fromEnvironment(
  'SCIENTIST_API_BASE_URL',
  defaultValue: 'http://localhost:8000',
);

/// When false, the app uses [MockScientistBackendClient] instead of HTTP.
/// True if [kScientistApiBaseUrl] is non-empty after trim.
bool get kUseRealScientistApi => kScientistApiBaseUrl.trim().isNotEmpty;
