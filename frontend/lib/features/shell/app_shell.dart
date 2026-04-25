import 'package:flutter/material.dart';

import '../../core/app_constants.dart';
import '../../core/theme/theme_context.dart';
import 'widgets/sidebar.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  double _sidebarWidth = kSidebarWidth;

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _sidebarWidth = (_sidebarWidth + details.delta.dx)
          .clamp(kSidebarMinWidth, kSidebarMaxWidth);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: _sidebarWidth,
            child: const Sidebar(),
          ),
          _SidebarResizeHandle(onDragUpdate: _handleDragUpdate),
          Expanded(
            child: SizedBox.expand(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarResizeHandle extends StatefulWidget {
  const _SidebarResizeHandle({required this.onDragUpdate});

  final GestureDragUpdateCallback onDragUpdate;

  @override
  State<_SidebarResizeHandle> createState() => _SidebarResizeHandleState();
}

class _SidebarResizeHandleState extends State<_SidebarResizeHandle> {
  bool _isHovered = false;
  bool _isDragging = false;

  bool get _isActive => _isHovered || _isDragging;

  @override
  Widget build(BuildContext context) {
    final Color handleColor = context.appColorScheme.primary;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onHorizontalDragUpdate: widget.onDragUpdate,
        onHorizontalDragStart: (_) => setState(() => _isDragging = true),
        onHorizontalDragEnd: (_) => setState(() => _isDragging = false),
        behavior: HitTestBehavior.translucent,
        child: SizedBox(
          width: 6,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: _isActive ? 3 : 1,
              decoration: BoxDecoration(
                color: _isActive
                    ? handleColor.withValues(alpha: 0.6)
                    : handleColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
