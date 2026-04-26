import 'package:flutter_test/flutter_test.dart';

import 'package:scientist_ai/core/api_config.dart';
import 'package:scientist_ai/core/app_routes.dart';
import 'package:scientist_ai/core/user_api_keys_navigation.dart';

void main() {
  test('redirectForUserApiKeysGate when mock API skips gating', () {
    if (kUseRealScientistApi) {
      return;
    }
    expect(
      redirectForUserApiKeysGate(
        hasAllProviderKeysReady: false,
        matchedLocation: kRouteHome,
      ),
      isNull,
    );
    expect(
      redirectForUserApiKeysGate(
        hasAllProviderKeysReady: false,
        matchedLocation: kRoutePlan,
      ),
      isNull,
    );
  });

  test('redirectForUserApiKeysGate when real API and keys missing forces home', () {
    if (!kUseRealScientistApi) {
      return;
    }
    expect(
      redirectForUserApiKeysGate(
        hasAllProviderKeysReady: false,
        matchedLocation: kRouteHome,
      ),
      isNull,
    );
    expect(
      redirectForUserApiKeysGate(
        hasAllProviderKeysReady: false,
        matchedLocation: kRoutePlan,
      ),
      kRouteHome,
    );
    expect(
      redirectForUserApiKeysGate(
        hasAllProviderKeysReady: false,
        matchedLocation: kRouteOpenAiApiKeys,
      ),
      kRouteHome,
    );
  });

  test('redirectForUserApiKeysGate when real API and keys ready allows navigation',
      () {
    if (!kUseRealScientistApi) {
      return;
    }
    expect(
      redirectForUserApiKeysGate(
        hasAllProviderKeysReady: true,
        matchedLocation: kRoutePlan,
      ),
      isNull,
    );
    expect(
      redirectForUserApiKeysGate(
        hasAllProviderKeysReady: true,
        matchedLocation: kRouteOpenAiApiKeys,
      ),
      isNull,
    );
  });
}
