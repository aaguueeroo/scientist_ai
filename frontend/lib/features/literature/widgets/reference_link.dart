import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens an http(s) URL in the platform browser.
Future<void> launchReferenceUrl(String url) async {
  final String t = url.trim();
  if (t.isEmpty) {
    return;
  }
  final Uri? u = Uri.tryParse(t);
  if (u == null || !(u.isScheme('http') || u.isScheme('https'))) {
    return;
  }
  if (await canLaunchUrl(u)) {
    await launchUrl(u, mode: LaunchMode.externalApplication);
  }
}

/// `https://doi.org/...` for a raw DOI string, or null if not linkable.
String? doiToResolverUrl(String doi) {
  final String t = doi.trim();
  if (t.isEmpty) {
    return null;
  }
  if (t == '10.0000/unspecified') {
    return null;
  }
  return 'https://doi.org/${Uri.encodeComponent(t)}';
}

/// Title that opens [pageUrl] when set; otherwise plain [Text].
class ReferenceTitleLink extends StatelessWidget {
  const ReferenceTitleLink({
    super.key,
    required this.title,
    this.pageUrl,
    required this.style,
  });

  final String title;
  final String? pageUrl;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final String? u = pageUrl?.trim();
    if (u != null && u.isNotEmpty) {
      final Color c = Theme.of(context).colorScheme.primary;
      return InkWell(
        onTap: () => unawaited(launchReferenceUrl(u)),
        child: Text(
          title,
          style: style?.copyWith(
            color: c,
            decoration: TextDecoration.underline,
            decorationColor: c,
          ),
        ),
      );
    }
    return Text(title, style: style);
  }
}
