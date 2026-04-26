import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'conversation_query_key.dart';

/// Persists the mapping `trimmed query -> (literature review id, plan id)` so
/// reopening a sidebar conversation can [GET] stored rows instead of
/// re-running agents. Keys are the user-visible research question string.
@immutable
class CachedSessionIds {
  const CachedSessionIds({
    required this.literatureReviewId,
    required this.planId,
  });

  final String literatureReviewId;
  final String planId;
}

const String _kPrefsKey = 'conversation_sessions_v1';

class ConversationSessionStore {
  ConversationSessionStore._(this._prefs);

  final SharedPreferences _prefs;

  static Future<ConversationSessionStore> open() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    return ConversationSessionStore._(p);
  }

  Map<String, dynamic> _readRaw() {
    final String? s = _prefs.getString(_kPrefsKey);
    if (s == null || s.isEmpty) {
      return <String, dynamic>{};
    }
    try {
      final Object? o = jsonDecode(s);
      if (o is Map<String, dynamic>) {
        return o;
      }
    } catch (_) {
      // ignore
    }
    return <String, dynamic>{};
  }

  CachedSessionIds? getIds(String query) {
    final String want = conversationQueryKey(query);
    if (want.isEmpty) {
      return null;
    }
    final Map<String, dynamic> m = _readRaw();
    Map<String, dynamic>? e = m[want] as Map<String, dynamic>?;
    e ??= _findEntryByNormalizedKey(m, want);
    if (e == null) {
      return null;
    }
    final String? lit = e['literatureReviewId'] as String?;
    final String? plan = e['planId'] as String?;
    if (lit == null || lit.isEmpty || plan == null || plan.isEmpty) {
      return null;
    }
    return CachedSessionIds(
      literatureReviewId: lit,
      planId: plan,
    );
  }

  Future<void> put(
    String query,
    String literatureReviewId,
    String planId,
  ) async {
    final String k = conversationQueryKey(query);
    if (k.isEmpty || literatureReviewId.isEmpty || planId.isEmpty) {
      return;
    }
    final Map<String, dynamic> m = _readRaw();
    m.removeWhere(
      (String key, Object? _) => conversationQueryKey(key) == k && key != k,
    );
    m[k] = <String, dynamic>{
      'literatureReviewId': literatureReviewId,
      'planId': planId,
    };
    await _prefs.setString(_kPrefsKey, jsonEncode(m));
  }

  Future<void> remove(String query) async {
    final String want = conversationQueryKey(query);
    if (want.isEmpty) {
      return;
    }
    final Map<String, dynamic> m = _readRaw();
    m.removeWhere(
      (String key, Object? _) => conversationQueryKey(key) == want,
    );
    await _prefs.setString(_kPrefsKey, jsonEncode(m));
  }
}

Map<String, dynamic>? _findEntryByNormalizedKey(
  Map<String, dynamic> m,
  String want,
) {
  for (final MapEntry<String, dynamic> ent in m.entries) {
    if (conversationQueryKey(ent.key) == want && ent.value is Map<String, dynamic>) {
      return ent.value as Map<String, dynamic>;
    }
  }
  return null;
}
