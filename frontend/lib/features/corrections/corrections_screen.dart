import 'package:flutter/material.dart';

import '../../core/app_constants.dart';
import '../../core/theme/theme_context.dart';

class CorrectionsScreen extends StatelessWidget {
  const CorrectionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(kSpace40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.inventory_2_outlined,
              size: 40,
              color: context.scientist.onSurfaceFaint,
            ),
            const SizedBox(height: kSpace16),
            Text('Correction Store', style: textTheme.titleMedium),
            const SizedBox(height: kSpace8),
            Text(
              'Coming soon',
              style: context.scientist.bodySecondary,
            ),
          ],
        ),
      ),
    );
  }
}
