import 'package:flutter/material.dart';

import '../../../../core/app_constants.dart';

class CorrectionActionBar extends StatelessWidget {
  const CorrectionActionBar({
    super.key,
    required this.onSave,
    required this.onCancel,
  });

  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        OutlinedButton(
          onPressed: onCancel,
          child: const Text('Cancel'),
        ),
        const SizedBox(width: kSpace12),
        FilledButton.icon(
          onPressed: onSave,
          icon: const Icon(Icons.check, size: 16),
          label: const Text('Save corrections'),
        ),
      ],
    );
  }
}

class CorrectionEnterButton extends StatelessWidget {
  const CorrectionEnterButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.edit_outlined, size: 16),
      label: const Text('Edit plan'),
    );
  }
}
