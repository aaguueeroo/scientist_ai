import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/user_api_keys_store.dart';
import '../../core/api_config.dart';
import '../../core/app_router.dart';
import 'setup_user_api_keys_dialog.dart';

/// Shows the API keys setup [Dialog] when the real API is enabled and keys are missing.
class UserApiKeysSetupHost extends StatefulWidget {
  const UserApiKeysSetupHost({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<UserApiKeysSetupHost> createState() => _UserApiKeysSetupHostState();
}

class _UserApiKeysSetupHostState extends State<UserApiKeysSetupHost> {
  bool _dialogLoopActive = false;

  Future<void> _runSetupDialogLoop() async {
    if (_dialogLoopActive) {
      return;
    }
    _dialogLoopActive = true;
    if (!mounted) {
      _dialogLoopActive = false;
      return;
    }
    final UserApiKeysStore store = context.read<UserApiKeysStore>();
    try {
      while (mounted && kUseRealScientistApi) {
        if (store.hasAllProviderKeysReady) {
          break;
        }
        final BuildContext? navContext = appRootNavigatorKey.currentContext;
        if (navContext == null || !navContext.mounted) {
          break;
        }
        await showDialog<void>(
          context: navContext,
          barrierDismissible: false,
          useRootNavigator: true,
          builder: (BuildContext dialogContext) {
            return const SetupUserApiKeysDialog();
          },
        );
      }
    } finally {
      _dialogLoopActive = false;
      if (mounted && kUseRealScientistApi && !store.hasAllProviderKeysReady) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _scheduleDialogLoop();
          }
        });
      }
    }
  }

  void _scheduleDialogLoop() {
    if (!kUseRealScientistApi) {
      return;
    }
    final UserApiKeysStore store = context.read<UserApiKeysStore>();
    if (store.hasAllProviderKeysReady || _dialogLoopActive) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _runSetupDialogLoop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    context.watch<UserApiKeysStore>();
    _scheduleDialogLoop();
    return widget.child;
  }
}
