import 'package:flutter/material.dart';

import '../../../core/app_constants.dart';
import '../../../core/theme/theme_context.dart';

class LiteratureEmpty extends StatelessWidget {
  const LiteratureEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.travel_explore,
            size: 40,
            color: context.scientist.onSurfaceFaint,
          ),
          const SizedBox(height: kSpace16),
          Text(
            'No prior research found',
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: kSpace8),
          Text(
            'Marie couldn\'t find existing work on this. You may be breaking new ground!',
            style: context.scientist.bodySecondary,
          ),
        ],
      ),
    );
  }
}
