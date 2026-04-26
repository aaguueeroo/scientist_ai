/// Third-party API keys the Marie Query client can supply to the backend.
enum AppProviderApiKeyKind {
  openAi,
  tavily,
}

extension AppProviderApiKeyKindX on AppProviderApiKeyKind {
  String get displayLabel {
    switch (this) {
      case AppProviderApiKeyKind.openAi:
        return 'OpenAI API key';
      case AppProviderApiKeyKind.tavily:
        return 'Tavily API key';
    }
  }

  /// Where the scientist can create or copy this key in the vendor’s console.
  Uri get platformKeysUrl {
    switch (this) {
      case AppProviderApiKeyKind.openAi:
        return Uri.parse('https://platform.openai.com/api-keys');
      case AppProviderApiKeyKind.tavily:
        return Uri.parse('https://app.tavily.com/home');
    }
  }

  /// Short explanation for the help tooltip (what Marie Query uses it for).
  String get usageTooltip {
    switch (this) {
      case AppProviderApiKeyKind.openAi:
        return 'Used for AI in Marie Query: checking literature, analyzing feedback on '
            'your experiment plan, and drafting the plan. Your key stays on this device '
            'and is sent only to the Marie Query server you configured.';
      case AppProviderApiKeyKind.tavily:
        return 'Used for web and literature search when Marie Query runs the literature '
            'review and when it gathers sources for your experiment plan. Your key stays '
            'on this device and is sent only to your Marie Query server.';
    }
  }
}
