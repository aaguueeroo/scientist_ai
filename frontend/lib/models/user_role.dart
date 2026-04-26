/// Identifies which "user role" the app is currently presenting.
///
/// Roles drive what the user sees in the sidebar and on a project plan
/// screen. In a real app this would be derived from the authenticated
/// account; for now it is mocked and switched manually from the sidebar
/// user menu.
enum UserRole {
  labScientist,
  funder,
}

extension UserRoleX on UserRole {
  String get displayLabel {
    switch (this) {
      case UserRole.labScientist:
        return 'Lab scientist';
      case UserRole.funder:
        return 'Funder / sponsor';
    }
  }

  String get switchLabel {
    switch (this) {
      case UserRole.labScientist:
        return 'Switch to Lab scientist';
      case UserRole.funder:
        return 'Switch to Funder / sponsor';
    }
  }
}
