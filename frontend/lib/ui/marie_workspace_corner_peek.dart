import 'package:flutter/material.dart';

import '../core/app_constants.dart';

/// Decorative Marie figure: bottom-left overlay, ignores pointer; use inside a
/// [Stack] after literature or plan content has finished loading.
class MarieWorkspaceCornerPeek extends StatelessWidget {
  const MarieWorkspaceCornerPeek({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Image.asset(
          'lib/assets/marie_curie_illustration.png',
          height: kMarieWorkspacePeekHeight,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
