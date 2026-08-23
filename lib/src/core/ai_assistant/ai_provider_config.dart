/// Which AI provider the assistant is currently configured to use.
///
/// Every value is served by the same `OpenAICompatibleAssistant` class
/// (spec: no per-provider subclasses) — this enum only carries the
/// user-facing preset label and its default endpoint/model, since Gemini,
/// ChatGPT, and DeepSeek/local models all speak the OpenAI chat-completions
/// wire format (Gemini via Google's official OpenAI-compatible endpoint).
enum AIProviderType {
  gemini(
    // No trailing slash: OpenAIClient rejects a baseUrl ending in "/" and
    // appends the request path (e.g. "/chat/completions") itself.
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
    // gemini-2.0-flash-exp was retired by Google on 2026-06-01. gemini-3.5-flash
    // (released 2026-05-19) has no announced shutdown date as of this writing —
    // re-check https://ai.google.dev/gemini-api/docs/changelog periodically,
    // since Google retires dated model snapshots on a rolling basis.
    defaultModel: 'gemini-3.5-flash',
  ),
  chatgpt(
    baseUrl: null, // OpenAIClient's own default (https://api.openai.com/v1)
    defaultModel: 'gpt-4',
  ),
  customOpenAI(baseUrl: null, defaultModel: null),
  managedDeepSeek(baseUrl: null, defaultModel: 'deepseek-chat');

  const AIProviderType({required this.baseUrl, required this.defaultModel});

  /// Fixed endpoint for this preset, or null when the endpoint is either the
  /// client SDK's own default (chatgpt) or user/deployment supplied
  /// (customOpenAI: entered by the user; managedDeepSeek: set by the app
  /// owner's deployment, see AIProviderConfig.managedDeepSeekBaseUrl).
  final String? baseUrl;

  /// Fixed model for this preset, or null when the model is user-supplied
  /// (customOpenAI).
  final String? defaultModel;

  static AIProviderType fromName(String? name) {
    return AIProviderType.values.firstWhere(
      (value) => value.name == name,
      orElse: () => AIProviderType.gemini,
    );
  }
}

/// Client-owned configuration describing which LLM the assistant talks to.
///
/// [AIProviderType.customOpenAI] requires [baseUrl], [apiKey], and [model]
/// to all be non-empty before it can be selected/used (see data-model.md).
class AIProviderConfig {
  final AIProviderType providerType;
  final String? apiKey;
  final String? baseUrl;
  final String? model;
  final String? installId;

  const AIProviderConfig({
    required this.providerType,
    this.apiKey,
    this.baseUrl,
    this.model,
    this.installId,
  });

  static const AIProviderConfig defaultConfig =
      AIProviderConfig(providerType: AIProviderType.gemini);

  /// Deployment-configured base URL for the managed DeepSeek proxy (spec
  /// FR-018: this app never bundles the proxy's DeepSeek key — it only needs
  /// to know where the app owner's already-deployed proxy lives). Supplied at
  /// build time so it never needs to be hardcoded in source or committed to
  /// this open-source repository.
  static const String managedDeepSeekBaseUrl =
      String.fromEnvironment('MANAGED_DEEPSEEK_BASE_URL');

  bool get isCustomOpenAIConfigured =>
      (baseUrl?.isNotEmpty ?? false) &&
      (apiKey?.isNotEmpty ?? false) &&
      (model?.isNotEmpty ?? false);

  AIProviderConfig copyWith({
    AIProviderType? providerType,
    String? apiKey,
    String? baseUrl,
    String? model,
    String? installId,
  }) {
    return AIProviderConfig(
      providerType: providerType ?? this.providerType,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      installId: installId ?? this.installId,
    );
  }
}
