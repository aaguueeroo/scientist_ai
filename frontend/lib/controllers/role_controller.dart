import 'package:flutter/foundation.dart';

import '../models/user_role.dart';

/// Holds the current "user role" for the app session.
///
/// Mocked: in a real app this would be derived from the authenticated
/// account. For now the user picks a role from the sidebar user menu and
/// the rest of the UI reacts via the standard `Provider` listening flow.
class RoleController extends ChangeNotifier {
  RoleController({UserRole initialRole = UserRole.funder})
      : _role = initialRole;

  UserRole _role;

  UserRole get role => _role;

  void setRole(UserRole next) {
    if (next == _role) {
      return;
    }
    _role = next;
    notifyListeners();
  }
}
