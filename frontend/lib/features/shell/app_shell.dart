import 'package:flutter/material.dart';

import '../../core/app_constants.dart';
import 'widgets/sidebar.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: <Widget>[
          const SizedBox(
            width: kSidebarWidth,
            child: Sidebar(),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
