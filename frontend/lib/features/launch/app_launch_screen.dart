import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
import '../../core/app_theme.dart';

/// Branded cold-start view: wordmark and animated subtitle.
class AppLaunchScreen extends StatefulWidget {
  const AppLaunchScreen({
    super.key,
    this.loadError,
    this.onRetry,
    this.embedsInStackedBackground = false,
  });

  final Object? loadError;
  final VoidCallback? onRetry;

  /// When true, omits the full-screen [ColoredBox]; the parent must paint
  /// [AppColors.background] so the launch fade does not expose transparency.
  final bool embedsInStackedBackground;

  @override
  State<AppLaunchScreen> createState() => _AppLaunchScreenState();
}

class _AppLaunchScreenState extends State<AppLaunchScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: kAppLaunchEntryAnimationDuration,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _entryController.forward();
      }
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> logoOpacity = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.42, curve: Curves.easeOutCubic),
    );
    final Animation<Offset> logoSlide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.42, curve: Curves.easeOutCubic),
      ),
    );
    final Animation<double> subtitleOpacity = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.3, 0.88, curve: Curves.easeOutCubic),
    );
    final Animation<Offset> subtitleSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.3, 0.88, curve: Curves.easeOutCubic),
      ),
    );
    final Widget content = SafeArea(
      child: Center(
        child: Builder(
          builder: (BuildContext themedContext) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: kSpace32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  FadeTransition(
                    opacity: logoOpacity,
                    child: SlideTransition(
                      position: logoSlide,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: kAppLaunchLogoMaxWidth,
                        ),
                        child: Image.asset(
                          kSidebarLogoAsset,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          semanticLabel: 'Marie Query',
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: kAppLaunchLogoSubtitleSpacing),
                  FadeTransition(
                    opacity: subtitleOpacity,
                    child: SlideTransition(
                      position: subtitleSlide,
                      child: Text(
                        kAppLaunchSubtitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(themedContext)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.2,
                            ),
                      ),
                    ),
                  ),
                  if (widget.loadError != null) ...<Widget>[
                    const SizedBox(height: kSpace24),
                    Text(
                      'Could not load saved settings. Check permissions and try again.',
                      textAlign: TextAlign.center,
                      style:
                          Theme.of(themedContext).textTheme.bodySmall?.copyWith(
                                color: AppColors.textTertiary,
                              ),
                    ),
                    const SizedBox(height: kSpace16),
                    TextButton(
                      onPressed: widget.onRetry,
                      child: const Text('Retry'),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
    return Theme(
      data: buildAppTheme(),
      child: widget.embedsInStackedBackground
          ? content
          : ColoredBox(
              color: AppColors.background,
              child: content,
            ),
    );
  }
}
