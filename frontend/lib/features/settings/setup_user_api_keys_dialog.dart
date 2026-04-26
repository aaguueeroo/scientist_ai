import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/user_api_keys_store.dart';
import '../../core/app_constants.dart';
import '../../core/theme/theme_context.dart';
import '../../models/app_provider_api_key_kind.dart';
import 'widgets/provider_api_key_field.dart';

/// First-run modal: collect OpenAI and Tavily API keys.
class SetupUserApiKeysDialog extends StatefulWidget {
  const SetupUserApiKeysDialog({super.key});

  @override
  State<SetupUserApiKeysDialog> createState() => _SetupUserApiKeysDialogState();
}

class _SetupUserApiKeysDialogState extends State<SetupUserApiKeysDialog> {
  final TextEditingController _openAiController = TextEditingController();
  final TextEditingController _tavilyController = TextEditingController();
  bool _obscureOpenAi = true;
  bool _obscureTavily = true;
  String? _inlineError;

  @override
  void dispose() {
    _openAiController.dispose();
    _tavilyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _inlineError = null);
    final UserApiKeysStore store = context.read<UserApiKeysStore>();
    final String? err = await store.saveOpenAiAndTavily(
      openAiSecret: _openAiController.text,
      tavilySecret: _tavilyController.text,
    );
    if (!mounted) {
      return;
    }
    if (err != null) {
      setState(() => _inlineError = err);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = context.appColorScheme;
    return AlertDialog(
      title: Text(
        'Connect your API keys',
        style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: kHomeMaxWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Marie Query needs an OpenAI key for AI steps and a Tavily key for '
                'literature and web search. Keys stay on this device and are sent only '
                'to the Marie Query server you use.',
                style: context.scientist.bodySecondary,
              ),
              const SizedBox(height: kSpace24),
              ProviderApiKeyField(
                kind: AppProviderApiKeyKind.openAi,
                controller: _openAiController,
                obscureText: _obscureOpenAi,
                onToggleObscure: () => setState(() => _obscureOpenAi = !_obscureOpenAi),
                hintText: 'sk-…',
              ),
              const SizedBox(height: kSpace24),
              ProviderApiKeyField(
                kind: AppProviderApiKeyKind.tavily,
                controller: _tavilyController,
                obscureText: _obscureTavily,
                onToggleObscure: () => setState(() => _obscureTavily = !_obscureTavily),
                hintText: 'tvly-…',
              ),
              if (_inlineError != null) ...<Widget>[
                const SizedBox(height: kSpace12),
                Text(
                  _inlineError!,
                  style: textTheme.bodySmall?.copyWith(color: scheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: _submit,
          child: const Text('Save and continue'),
        ),
      ],
    );
  }
}
