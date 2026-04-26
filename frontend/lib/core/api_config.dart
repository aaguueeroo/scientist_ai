/// Base URL of the AI Scientist FastAPI app (no trailing slash), e.g.
/// `http://localhost:8000` or (Android emulator) `http://10.0.2.2:8000`.
///
/// Override for local dev:
/// `flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000`
const String kScientistApiBaseUrl = String.fromEnvironment(
  'SCIENTIST_API_BASE_URL',
  defaultValue: 'http://localhost:8000',
);

bool get kUseRealScientistApi => kScientistApiBaseUrl.trim().isNotEmpty;
