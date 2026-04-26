import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_config.dart';
import '../core/user_api_keys_constants.dart';
import '../models/app_provider_api_key_kind.dart';
/// Persists user-supplied OpenAI and Tavily API keys (secure storage + in-memory cache for HTTP).
class UserApiKeysStore extends ChangeNotifier {
  UserApiKeysStore._(
    this._prefs,
    this._secure,
  );

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  String? _cachedOpenAi;
  String? _cachedTavily;

  static Future<UserApiKeysStore> open() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    const FlutterSecureStorage secure = FlutterSecureStorage();
    final UserApiKeysStore store = UserApiKeysStore._(prefs, secure);
    await store._migrateLegacyOpenAiIfNeeded();
    await store._reloadFromDisk();
    return store;
  }

  String _storageKeyFor(AppProviderApiKeyKind kind) {
    switch (kind) {
      case AppProviderApiKeyKind.openAi:
        return kUserSecretStorageKeyOpenAi;
      case AppProviderApiKeyKind.tavily:
        return kUserSecretStorageKeyTavily;
    }
  }

  Future<void> _migrateLegacyOpenAiIfNeeded() async {
    try {
      final String? existing =
          await _secure.read(key: kUserSecretStorageKeyOpenAi);
      if (existing != null && existing.trim().isNotEmpty) {
        return;
      }
      final String? activeId = _prefs.getString(kLegacyOpenAiApiKeyActiveIdPrefsKey);
      if (activeId == null || activeId.isEmpty) {
        return;
      }
      final String? secret = await _secure.read(
        key: '$kLegacyOpenAiSecretStoragePrefix$activeId',
      );
      if (secret == null || secret.trim().isEmpty) {
        return;
      }
      await _secure.write(
        key: kUserSecretStorageKeyOpenAi,
        value: secret.trim(),
      );
    } catch (e, st) {
      // ignore: avoid_print
      print('UserApiKeysStore._migrateLegacyOpenAiIfNeeded failed: $e\n$st');
    }
  }

  Future<void> _reloadFromDisk() async {
    try {
      _cachedOpenAi = await _readTrimmed(kUserSecretStorageKeyOpenAi);
      _cachedTavily = await _readTrimmed(kUserSecretStorageKeyTavily);
    } catch (e, st) {
      // ignore: avoid_print
      print('UserApiKeysStore._reloadFromDisk failed: $e\n$st');
      _cachedOpenAi = null;
      _cachedTavily = null;
    }
    notifyListeners();
  }

  Future<String?> _readTrimmed(String storageKey) async {
    final String? raw = await _secure.read(key: storageKey);
    if (raw == null) {
      return null;
    }
    final String t = raw.trim();
    return t.isEmpty ? null : t;
  }

  /// Non-empty trimmed OpenAI secret for HTTP, or null.
  String? get activeOpenAiSecretForHttpHeader {
    final String? s = _cachedOpenAi;
    if (s == null) {
      return null;
    }
    final String t = s.trim();
    return t.isEmpty ? null : t;
  }

  /// Non-empty trimmed Tavily secret for HTTP, or null.
  String? get activeTavilySecretForHttpHeader {
    final String? s = _cachedTavily;
    if (s == null) {
      return null;
    }
    final String t = s.trim();
    return t.isEmpty ? null : t;
  }

  bool get hasOpenAiKeyReady => activeOpenAiSecretForHttpHeader != null;

  bool get hasTavilyKeyReady => activeTavilySecretForHttpHeader != null;

  bool get hasAllProviderKeysReady => hasOpenAiKeyReady && hasTavilyKeyReady;

  /// When true, first-run onboarding should block the main shell (real API only).
  bool get needsUserApiKeysOnboarding =>
      kUseRealScientistApi && !hasAllProviderKeysReady;

  static bool isPlausibleOpenAiSecret(String value) {
    final String t = value.trim();
    return t.length >= 20 && t.startsWith('sk-');
  }

  static bool isPlausibleTavilySecret(String value) {
    final String t = value.trim();
    if (t.length < 12) {
      return false;
    }
    return t.startsWith('tvly') || t.startsWith('tvl');
  }

  static String maskSecretPreview(String secret) {
    final String t = secret.trim();
    if (t.length <= 8) {
      return '••••••••';
    }
    return '${t.substring(0, 4)}…${t.substring(t.length - 4)}';
  }

  /// Masked hint for UI from in-memory cache (updates after [notifyListeners]).
  String maskedDisplayLine(AppProviderApiKeyKind kind) {
    switch (kind) {
      case AppProviderApiKeyKind.openAi:
        final String? s = _cachedOpenAi;
        if (s == null || s.trim().isEmpty) {
          return '(not set)';
        }
        return maskSecretPreview(s);
      case AppProviderApiKeyKind.tavily:
        final String? s = _cachedTavily;
        if (s == null || s.trim().isEmpty) {
          return '(not set)';
        }
        return maskSecretPreview(s);
    }
  }

  /// Validates and saves one provider key. Pass trimmed secret.
  Future<String?> saveKey(AppProviderApiKeyKind kind, String secret) async {
    final String t = secret.trim();
    if (t.isEmpty) {
      return 'Please paste your ${kind.displayLabel}.';
    }
    switch (kind) {
      case AppProviderApiKeyKind.openAi:
        if (!isPlausibleOpenAiSecret(t)) {
          return 'OpenAI keys usually start with sk- and are at least 20 characters.';
        }
        break;
      case AppProviderApiKeyKind.tavily:
        if (!isPlausibleTavilySecret(t)) {
          return 'Tavily keys usually start with tvly- (copy the key from your Tavily account).';
        }
        break;
    }
    try {
      await _secure.write(key: _storageKeyFor(kind), value: t);
      switch (kind) {
        case AppProviderApiKeyKind.openAi:
          _cachedOpenAi = t;
          break;
        case AppProviderApiKeyKind.tavily:
          _cachedTavily = t;
          break;
      }
      notifyListeners();
      return null;
    } catch (e, st) {
      // ignore: avoid_print
      print('UserApiKeysStore.saveKey failed: $e\n$st');
      return 'Could not save this key. Please try again.';
    }
  }

  Future<String?> clearKey(AppProviderApiKeyKind kind) async {
    try {
      await _secure.delete(key: _storageKeyFor(kind));
      switch (kind) {
        case AppProviderApiKeyKind.openAi:
          _cachedOpenAi = null;
          break;
        case AppProviderApiKeyKind.tavily:
          _cachedTavily = null;
          break;
      }
      notifyListeners();
      return null;
    } catch (e, st) {
      // ignore: avoid_print
      print('UserApiKeysStore.clearKey failed: $e\n$st');
      return 'Could not remove this key.';
    }
  }

  /// Saves both keys in one transaction-style flow (onboarding). Either returns first error.
  Future<String?> saveOpenAiAndTavily({
    required String openAiSecret,
    required String tavilySecret,
  }) async {
    final String? openErr =
        await saveKey(AppProviderApiKeyKind.openAi, openAiSecret);
    if (openErr != null) {
      return openErr;
    }
    final String? tvErr =
        await saveKey(AppProviderApiKeyKind.tavily, tavilySecret);
    if (tvErr != null) {
      return tvErr;
    }
    return null;
  }

  Future<void> reload() async {
    await _reloadFromDisk();
  }
}
