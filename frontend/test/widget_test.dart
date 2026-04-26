// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use the WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scientist_ai/app.dart';
import 'package:scientist_ai/controllers/user_api_keys_store.dart';
import 'package:scientist_ai/core/api_config.dart';
import 'package:scientist_ai/core/user_api_keys_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Renders Marie Query home', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final UserApiKeysStore store;
    if (kUseRealScientistApi) {
      const String openAi = 'sk-12345678901234567890ab';
      const String tavily = 'tvly-test123456789012';
      FlutterSecureStorage.setMockInitialValues(<String, String>{
        kUserSecretStorageKeyOpenAi: openAi,
        kUserSecretStorageKeyTavily: tavily,
      });
      SharedPreferences.setMockInitialValues(<String, Object>{});
      store = await UserApiKeysStore.open();
    } else {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
      store = await UserApiKeysStore.open();
    }
    await tester.pumpWidget(ScientistApp(userApiKeysStore: store));
    await tester.pumpAndSettle();
    expect(find.text('Hi! What are we investigating today?'), findsOneWidget);
  });
}
