import 'package:flutter/foundation.dart';

/// Drives the Marie corner illustration painted in [AppShell] (outside nested
/// [Navigator] clips).
class MarieShellPeekController extends ChangeNotifier {
  bool _visible = false;

  bool get visible => _visible;

  void setMarieVisible(bool value) {
    if (_visible == value) {
      return;
    }
    _visible = value;
    notifyListeners();
  }
}
