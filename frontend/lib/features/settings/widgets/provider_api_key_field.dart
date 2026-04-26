import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_constants.dart';
import '../../../core/theme/theme_context.dart';
import '../../../models/app_provider_api_key_kind.dart';

/// Label, help tooltip, “Get your key” link, and secret field for one provider.
class ProviderApiKeyField extends StatelessWidget {
  const ProviderApiKeyField({
    super.key,
    required this.kind,
    required this.controller,
    required this.obscureText,
    required this.onToggleObscure,
    this.hintText,
  });

  final AppProviderApiKeyKind kind;
  final TextEditingController controller;
  final bool obscureText;
  final VoidCallback onToggleObscure;
  final String? hintText;

  Future<void> _openPlatform() async {
    final Uri uri = kind.platformKeysUrl;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e, st) {
      // ignore: avoid_print
      print('ProviderApiKeyField: launchUrl failed: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Text(
              kind.displayLabel,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: kSpace4),
            Tooltip(
              message: kind.usageTooltip,
              constraints: const BoxConstraints(
                maxWidth: kProviderApiKeyHelpTooltipMaxWidth,
              ),
              decoration: BoxDecoration(
                color: scheme.inverseSurface,
                borderRadius: BorderRadius.circular(kRadius),
              ),
              textStyle: textTheme.bodySmall?.copyWith(
                color: scheme.onInverseSurface,
              ),
              waitDuration: const Duration(milliseconds: 200),
              showDuration: const Duration(seconds: 8),
              child: MouseRegion(
                cursor: SystemMouseCursors.help,
                child: IconButton(
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                  style: IconButton.styleFrom(
                    foregroundColor: context.scientist.onSurfaceFaint,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.help_outline_rounded, size: 20),
                ),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _openPlatform,
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Get your key'),
            ),
          ],
        ),
        const SizedBox(height: kSpace8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hintText,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: obscureText ? 'Show key' : 'Hide key',
              onPressed: onToggleObscure,
              icon: Icon(
                obscureText
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
