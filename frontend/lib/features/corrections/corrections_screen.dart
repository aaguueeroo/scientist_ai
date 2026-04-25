import 'package:flutter/material.dart';

import '../../core/app_constants.dart';

class CorrectionsScreen extends StatelessWidget {
  const CorrectionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(kSpaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.inventory_2_outlined, size: 48),
            SizedBox(height: kSpaceM),
            Text('Correction Store'),
            SizedBox(height: kSpaceS),
            Text('Coming soon'),
          ],
        ),
      ),
    );
  }
}
