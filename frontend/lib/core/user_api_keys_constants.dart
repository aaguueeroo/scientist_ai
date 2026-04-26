/// [FlutterSecureStorage] keys for user-supplied provider secrets (v2, one per provider).
const String kUserSecretStorageKeyOpenAi = 'user_provider_secret_v2_openai';
const String kUserSecretStorageKeyTavily = 'user_provider_secret_v2_tavily';

/// Legacy OpenAI multi-key storage (migration only).
const String kLegacyOpenAiApiKeysMetadataPrefsKey = 'openai_api_keys_metadata_v1';
const String kLegacyOpenAiApiKeyActiveIdPrefsKey = 'openai_api_key_active_id_v1';
const String kLegacyOpenAiSecretStoragePrefix = 'openai_secret_v1_';

/// HTTP headers sent to the backend (see `docs/be_user_openai_api_keys.md`).
const String kOpenAiApiKeyHttpHeader = 'X-OpenAI-API-Key';
const String kTavilyApiKeyHttpHeader = 'X-Tavily-API-Key';
