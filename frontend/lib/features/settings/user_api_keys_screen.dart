import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_constants.dart';
import '../../core/app_routes.dart';
import 'user_api_keys_manage_panel.dart';

/// Manage OpenAI and Tavily API keys used with your Marie Query server.
class UserApiKeysScreen extends StatelessWidget {
  const UserApiKeysScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API keys'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(kRouteHome);
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(kSpace16),
        child: const UserApiKeysManagePanel(),
      ),
    );
  }
}
