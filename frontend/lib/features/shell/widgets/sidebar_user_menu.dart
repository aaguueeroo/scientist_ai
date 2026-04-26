import 'package:flutter/material.dart';

import '../../../core/app_constants.dart';
import '../../../core/theme/theme_context.dart';
import '../../../models/user_role.dart';
import 'user_avatar.dart';

/// Bottom-of-sidebar user "card" that opens a menu for: Settings (mocked)
/// and switching between [UserRole]s.
///
/// In a real app the role switch would be replaced by sign-out + re-login;
/// for now it's a manual toggle to demonstrate the role-aware UI.
class SidebarUserMenu extends StatelessWidget {
  const SidebarUserMenu({
    super.key,
    required this.userName,
    required this.userAvatarUrl,
    required this.role,
    required this.onSelectRole,
    required this.onOpenSettings,
    required this.onOpenApiKeys,
  });

  final String userName;
  final String userAvatarUrl;
  final UserRole role;
  final ValueChanged<UserRole> onSelectRole;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenApiKeys;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.appColorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: kSpace8,
        vertical: kSpace8,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: scheme.outline.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
      ),
      child: MenuAnchor(
        alignmentOffset: const Offset(0, -8),
        style: MenuStyle(
          backgroundColor: WidgetStateProperty.all<Color>(scheme.surface),
          elevation: WidgetStateProperty.all<double>(4),
          shape: WidgetStateProperty.all<OutlinedBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(kRadius),
              side: BorderSide(
                color: scheme.outline.withValues(alpha: 0.25),
              ),
            ),
          ),
        ),
        builder: (
          BuildContext context,
          MenuController controller,
          Widget? child,
        ) {
          return _UserCard(
            userName: userName,
            userAvatarUrl: userAvatarUrl,
            role: role,
            isOpen: controller.isOpen,
            onTap: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
          );
        },
        menuChildren: <Widget>[
          MenuItemButton(
            leadingIcon: Icon(
              Icons.settings_outlined,
              size: 16,
              color: scheme.onSurface,
            ),
            onPressed: onOpenSettings,
            child: Text('Settings', style: textTheme.bodyMedium),
          ),
          MenuItemButton(
            leadingIcon: Icon(
              Icons.key_outlined,
              size: 16,
              color: scheme.onSurface,
            ),
            onPressed: onOpenApiKeys,
            child: Text('API keys', style: textTheme.bodyMedium),
          ),
          const Divider(height: 1),
          for (final UserRole option in UserRole.values)
            MenuItemButton(
              leadingIcon: Icon(
                option == UserRole.labScientist
                    ? Icons.science_outlined
                    : Icons.account_balance_outlined,
                size: 16,
                color: option == role ? scheme.primary : scheme.onSurface,
              ),
              trailingIcon: option == role
                  ? Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: scheme.primary,
                    )
                  : null,
              onPressed: () => onSelectRole(option),
              child: Text(
                option.switchLabel,
                style: textTheme.bodyMedium?.copyWith(
                  color: option == role ? scheme.primary : null,
                  fontWeight: option == role ? FontWeight.w600 : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _UserCard extends StatefulWidget {
  const _UserCard({
    required this.userName,
    required this.userAvatarUrl,
    required this.role,
    required this.isOpen,
    required this.onTap,
  });

  final String userName;
  final String userAvatarUrl;
  final UserRole role;
  final bool isOpen;
  final VoidCallback onTap;

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.appColorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color background = widget.isOpen
        ? scheme.primaryContainer
        : (_isHovered ? scheme.surface : Colors.transparent);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(kRadius - 2),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: kSpace12,
            vertical: kSpace8,
          ),
          child: Row(
            children: <Widget>[
              UserAvatar(
                name: widget.userName,
                imageUrl: widget.userAvatarUrl,
                size: 32,
              ),
              const SizedBox(width: kSpace12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.role.displayLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.scientist.bodyTertiary,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: kSpace8),
              Icon(
                Icons.unfold_more_rounded,
                size: 16,
                color: context.scientist.onSurfaceFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
