import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/marie_shell_peek_controller.dart';

/// Pushes [MarieShellPeekController] from the active route and clears on
/// dispose (e.g. leaving the screen).
class MarieShellPeekSync extends StatefulWidget {
  const MarieShellPeekSync({
    super.key,
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  State<MarieShellPeekSync> createState() => _MarieShellPeekSyncState();
}

class _MarieShellPeekSyncState extends State<MarieShellPeekSync> {
  MarieShellPeekController? _peek;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _peek ??= context.read<MarieShellPeekController>();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _push());
  }

  @override
  void didUpdateWidget(covariant MarieShellPeekSync oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _push());
    }
  }

  void _push() {
    if (!mounted || _peek == null) {
      return;
    }
    _peek!.setMarieVisible(widget.visible);
  }

  @override
  void dispose() {
    _peek?.setMarieVisible(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
