import 'api_config.dart';
import 'app_routes.dart';

/// GoRouter redirect helper: keep users on [kRouteHome] until required keys exist
/// (real API only). Setup is shown as a dialog by [UserApiKeysSetupHost], not a route.
String? redirectForUserApiKeysGate({
  required bool hasAllProviderKeysReady,
  required String matchedLocation,
}) {
  if (!kUseRealScientistApi) {
    return null;
  }
  if (!hasAllProviderKeysReady) {
    if (matchedLocation == kRouteHome) {
      return null;
    }
    return kRouteHome;
  }
  return null;
}
