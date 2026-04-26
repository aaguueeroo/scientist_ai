import 'package:flutter/widgets.dart';

import 'app.dart';
import 'controllers/user_api_keys_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final UserApiKeysStore userApiKeysStore = await UserApiKeysStore.open();
  runApp(ScientistApp(userApiKeysStore: userApiKeysStore));
}
