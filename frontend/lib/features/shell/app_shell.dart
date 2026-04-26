import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/marie_shell_peek_controller.dart';
import '../../core/app_constants.dart';
import '../../core/app_routes.dart' show kBranchConversation;
import '../../core/theme/theme_context.dart';
import '../../ui/marie_workspace_corner_peek.dart';
import 'widgets/sidebar.dart';
import 'workspace_main_panel_insets.dart';

/// Persistent shell that hosts the sidebar plus the active branch content.
///
/// The shell itself is built once for the lifetime of the app (by
/// [StatefulShellRoute.indexedStack]) so the sidebar stays mounted while the
/// branch content swaps in/out.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with SingleTickerProviderStateMixin {
  double _sidebarWidth = kSidebarWidth;
  late final AnimationController _coldStartRevealController;
  late final Animation<double> _coldStartRevealOpacity;
  late final Animation<Offset> _coldStartRevealSlide;

  @override
  void initState() {
    super.initState();
    _coldStartRevealController = AnimationController(
      vsync: this,
      duration: kAppShellColdStartRevealDuration,
    );
    _coldStartRevealOpacity = Tween<double>(
      begin: kAppShellColdStartRevealOpacityBegin,
      end: kAppShellColdStartRevealOpacityEnd,
    ).animate(
      CurvedAnimation(
        parent: _coldStartRevealController,
        curve: Curves.easeOutCubic,
      ),
    );
    _coldStartRevealSlide = Tween<Offset>(
      begin: const Offset(0, kAppShellColdStartRevealSlideFraction),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _coldStartRevealController,
        curve: Curves.easeOutCubic,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _coldStartRevealController.forward();
      }
    });
  }

  @override
  void dispose() {
    _coldStartRevealController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationShell.currentIndex !=
        widget.navigationShell.currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        context.read<MarieShellPeekController>().setMarieVisible(false);
      });
    }
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _sidebarWidth = (_sidebarWidth + details.delta.dx)
          .clamp(kSidebarMinWidth, kSidebarMaxWidth);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _coldStartRevealOpacity,
        child: SlideTransition(
          position: _coldStartRevealSlide,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                width: _sidebarWidth,
                child: Sidebar(navigationShell: widget.navigationShell),
              ),
              _SidebarResizeHandle(onDragUpdate: _handleDragUpdate),
              Expanded(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final double panelWidth = constraints.maxWidth;
                    final double contentWidth =
                        math.min(panelWidth, kContentMaxWidth);
                    final double leftGutter = (panelWidth - contentWidth) / 2;
                    final double bottomPad =
                        MediaQuery.viewPaddingOf(context).bottom + kSpace8;
                    return Stack(
                      clipBehavior: Clip.none,
                      fit: StackFit.expand,
                      children: <Widget>[
                        Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: kContentMaxWidth,
                            ),
                            child: WorkspaceMainPanelInsets(
                              leftGutter: leftGutter,
                              child: widget.navigationShell,
                            ),
                          ),
                        ),
                        Consumer<MarieShellPeekController>(
                          builder: (
                            BuildContext context,
                            MarieShellPeekController peek,
                            Widget? _,
                          ) {
                            final bool onConversationBranch =
                                widget.navigationShell.currentIndex ==
                                    kBranchConversation;
                            if (!peek.visible || !onConversationBranch) {
                              return const SizedBox.shrink();
                            }
                            return Positioned(
                              left: marieWorkspacePeekLeftForGutter(leftGutter),
                              bottom: bottomPad,
                              child: const MarieWorkspaceCornerPeek(),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
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
