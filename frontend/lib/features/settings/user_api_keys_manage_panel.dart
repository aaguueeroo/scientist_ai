import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/user_api_keys_store.dart';
import '../../core/app_constants.dart';
import '../../core/theme/theme_context.dart';
import '../../models/app_provider_api_key_kind.dart';
import 'widgets/provider_api_key_field.dart';

/// OpenAI + Tavily key fields (save/remove per provider). Used by [UserApiKeysScreen]
/// and by [showManageUserApiKeysDialog] from the desktop app menu.
class UserApiKeysManagePanel extends StatefulWidget {
  const UserApiKeysManagePanel({super.key});

  @override
  State<UserApiKeysManagePanel> createState() => _UserApiKeysManagePanelState();
}

class _UserApiKeysManagePanelState extends State<UserApiKeysManagePanel> {
  final TextEditingController _openAiController = TextEditingController();
  final TextEditingController _tavilyController = TextEditingController();
  bool _obscureOpenAi = true;
  bool _obscureTavily = true;

  @override
  void dispose() {
    _openAiController.dispose();
    _tavilyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Consumer<UserApiKeysStore>(
      builder: (
        BuildContext context,
        UserApiKeysStore store,
        Widget? child,
      ) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Paste the keys from your OpenAI and Tavily accounts. They are stored '
              'securely on this device and sent only to your Marie Query server when '
              'you run features that need them.',
              style: context.scientist.bodySecondary,
            ),
            const SizedBox(height: kSpace24),
            _KeyCard(
              kind: AppProviderApiKeyKind.openAi,
              store: store,
              controller: _openAiController,
              obscureText: _obscureOpenAi,
              onToggleObscure: () => setState(() => _obscureOpenAi = !_obscureOpenAi),
              textTheme: textTheme,
            ),
            const SizedBox(height: kSpace16),
            _KeyCard(
              kind: AppProviderApiKeyKind.tavily,
              store: store,
              controller: _tavilyController,
              obscureText: _obscureTavily,
              onToggleObscure: () => setState(() => _obscureTavily = !_obscureTavily),
              textTheme: textTheme,
            ),
          ],
        );
      },
    );
  }
}

class _KeyCard extends StatelessWidget {
  const _KeyCard({
    required this.kind,
    required this.store,
    required this.controller,
    required this.obscureText,
    required this.onToggleObscure,
    required this.textTheme,
  });

  final AppProviderApiKeyKind kind;
  final UserApiKeysStore store;
  final TextEditingController controller;
  final bool obscureText;
  final VoidCallback onToggleObscure;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(kSpace16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ProviderApiKeyField(
              kind: kind,
              controller: controller,
              obscureText: obscureText,
              onToggleObscure: onToggleObscure,
              hintText: kind == AppProviderApiKeyKind.openAi ? 'sk-…' : 'tvly-…',
            ),
            const SizedBox(height: kSpace12),
            Text(
              'Saved on this device:',
              style: textTheme.labelMedium,
            ),
            const SizedBox(height: kSpace4),
            Text(
              store.maskedDisplayLine(kind),
              style: context.scientist.bodyTertiary,
            ),
            const SizedBox(height: kSpace16),
            Row(
              children: <Widget>[
                FilledButton(
                  onPressed: () async {
                    final String? err = await store.saveKey(kind, controller.text);
                    if (!context.mounted) {
                      return;
                    }
                    if (err != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(err)),
                      );
                    } else {
                      controller.clear();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${kind.displayLabel} saved.')),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
                const SizedBox(width: kSpace12),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () async {
                    final String? err = await store.clearKey(kind);
                    if (!context.mounted) {
                      return;
                    }
                    controller.clear();
                    if (err != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(err)),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${kind.displayLabel} removed.')),
                      );
                    }
                  },
                  child: const Text('Remove'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Desktop app menu: same API keys UI as the full screen, in a modal dialog.
Future<void> showManageUserApiKeysDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('API keys'),
        content: SizedBox(
          width: kHomeMaxWidth,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 520),
            child: SingleChildScrollView(
              child: UserApiKeysManagePanel(),
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}
