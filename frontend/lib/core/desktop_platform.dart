import 'package:flutter/foundation.dart';

/// Whether to attach [PlatformMenuBar] (native app menu on macOS / Windows).
bool get kSupportsDesktopNativeAppMenu {
  if (kIsWeb) {
    return false;
  }
  return defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows;
}
