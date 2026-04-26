import 'package:flutter/material.dart';

import '../../../core/app_constants.dart';
import '../../../core/theme/theme_context.dart';
import '../../../ui/marie_loading_lottie.dart';

class LiteratureLoading extends StatelessWidget {
  const LiteratureLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: kSpace32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const MarieLoadingLottie(),
            const SizedBox(height: kSpace24),
            Text(
              'Reviewing the literature…',
              style: context.scientist.bodySecondary,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
