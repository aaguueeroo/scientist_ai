import 'package:flutter/material.dart';

import '../core/app_constants.dart';

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: kSpace12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: textTheme.titleLarge),
                ?subtitle == null
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(top: kSpace4),
                        child: Text(subtitle!, style: textTheme.bodySmall),
                      ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
