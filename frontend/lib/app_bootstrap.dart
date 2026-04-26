import 'package:flutter/material.dart';

import 'app.dart';
import 'controllers/user_api_keys_store.dart';
import 'core/app_colors.dart';
import 'core/app_constants.dart';
import 'core/app_theme.dart';
import 'features/launch/app_launch_screen.dart';

/// Shows the launch screen while [UserApiKeysStore.open] runs, then fades into [ScientistApp].
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap>
    with SingleTickerProviderStateMixin {
  UserApiKeysStore? _store;
  Object? _loadError;
  bool _showApp = false;
  bool _showLaunchOverlay = true;
  late final Stopwatch _splashStopwatch;
  late final AnimationController _exitController;
  late final Animation<double> _exitOpacity;

  @override
  void initState() {
    super.initState();
    _splashStopwatch = Stopwatch()..start();
    _exitController = AnimationController(
      vsync: this,
      duration: kAppLaunchExitFadeDuration,
    );
    _exitOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInOut),
    );
    _openStore();
  }

  Future<void> _openStore() async {
    try {
      final UserApiKeysStore store = await UserApiKeysStore.open();
      if (!mounted) {
        return;
      }
      setState(() {
        _store = store;
        _loadError = null;
      });
      await _finishSplashIfReady();
    } catch (e, st) {
      debugPrint('UserApiKeysStore.open failed: $e\n$st');
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = e;
        _store = null;
      });
    }
  }

  Future<void> _finishSplashIfReady() async {
    if (_store == null) {
      return;
    }
    final Duration elapsed = _splashStopwatch.elapsed;
    final Duration remaining = kAppLaunchMinVisibleDuration - elapsed;
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }
    if (!mounted || _store == null) {
      return;
    }
    _exitController.value = 0;
    setState(() {
      _showApp = true;
      _showLaunchOverlay = true;
    });
    await _exitController.forward();
    if (!mounted) {
      return;
    }
    setState(() {
      _showLaunchOverlay = false;
    });
  }

  void _onRetry() {
    setState(() {
      _loadError = null;
    });
    _openStore();
  }

  @override
  void dispose() {
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showApp && _store != null) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          alignment: Alignment.topLeft,
          fit: StackFit.expand,
          children: <Widget>[
            ScientistApp(userApiKeysStore: _store!),
            if (_showLaunchOverlay)
              IgnorePointer(
                child: FadeTransition(
                  opacity: _exitOpacity,
                  child: const ColoredBox(
                    color: AppColors.background,
                    child: AppLaunchScreen(
                      embedsInStackedBackground: true,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      themeMode: ThemeMode.dark,
      home: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const ColoredBox(color: AppColors.background),
          FadeTransition(
            opacity: _exitOpacity,
            child: AppLaunchScreen(
              loadError: _loadError,
              onRetry: _loadError != null ? _onRetry : null,
              embedsInStackedBackground: true,
            ),
          ),
        ],
      ),
    );
  }
}
