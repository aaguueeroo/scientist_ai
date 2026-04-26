import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [url] in the platform browser. Logs and no-ops on failure.
Future<void> launchReferenceUrl(String url) async {
  final Uri? uri = Uri.tryParse(url);
  if (uri == null ||
      !uri.hasScheme ||
      (uri.scheme != 'http' && uri.scheme != 'https')) {
    developer.log(
      'launchReferenceUrl: invalid url "$url"',
      name: 'reference_link',
    );
    return;
  }
  try {
    final bool launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      developer.log(
        'launchReferenceUrl: could not launch "$url"',
        name: 'reference_link',
      );
    }
  } catch (err, stackTrace) {
    developer.log(
      'launchReferenceUrl: error for "$url": $err',
      error: err,
      stackTrace: stackTrace,
      name: 'reference_link',
    );
  }
}

/// Resolver URL for [doi], or null if it cannot be normalized to a link.
String? doiToResolverUrl(String doi) {
  String normalized = doi.trim();
  if (normalized.isEmpty) {
    return null;
  }
  final String lower = normalized.toLowerCase();
  if (lower.startsWith('doi:')) {
    normalized = normalized.substring(normalized.indexOf(':') + 1).trim();
  } else if (lower.startsWith('https://doi.org/')) {
    return normalized;
  } else if (lower.startsWith('http://doi.org/')) {
    return 'https://doi.org/${normalized.substring('http://doi.org/'.length)}';
  }
  if (normalized.isEmpty) {
    return null;
  }
  return 'https://doi.org/$normalized';
}

/// Tappable title when [pageUrl] is a valid http(s) URL; otherwise plain text.
class ReferenceTitleLink extends StatelessWidget {
  const ReferenceTitleLink({
    super.key,
    required this.title,
    this.pageUrl,
    this.style,
  });

  final String title;
  final String? pageUrl;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final String? raw = pageUrl?.trim();
    if (raw == null || raw.isEmpty) {
      return Text(title, style: style);
    }
    final Uri? uri = Uri.tryParse(raw);
    final bool canLaunch = uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https');
    if (!canLaunch) {
      return Text(title, style: style);
    }
    final Color c = Theme.of(context).colorScheme.primary;
    final TextStyle base =
        style ?? DefaultTextStyle.of(context).style;
    return InkWell(
      onTap: () => unawaited(launchReferenceUrl(uri.toString())),
      child: Text(
        title,
        style: base.copyWith(
          color: c,
          decoration: TextDecoration.underline,
          decorationColor: c,
        ),
      ),
    );
  }
}
