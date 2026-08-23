import 'package:flutter_test/flutter_test.dart';
import 'package:obsi/src/core/ai_assistant/ai_provider_config.dart';

void main() {
  group('AIProviderType', () {
    test('fromName resolves known names', () {
      expect(
          AIProviderType.fromName('customOpenAI'), AIProviderType.customOpenAI);
      expect(AIProviderType.fromName('managedDeepSeek'),
          AIProviderType.managedDeepSeek);
      expect(AIProviderType.fromName('chatgpt'), AIProviderType.chatgpt);
    });

    test('fromName defaults to gemini for unknown/null names', () {
      expect(AIProviderType.fromName(null), AIProviderType.gemini);
      expect(AIProviderType.fromName('not-a-provider'), AIProviderType.gemini);
    });
  });

  group('AIProviderConfig.isCustomOpenAIConfigured', () {
    test('is false when providerType is customOpenAI but fields are missing',
        () {
      const config =
          AIProviderConfig(providerType: AIProviderType.customOpenAI);
      expect(config.isCustomOpenAIConfigured, isFalse);
    });

    test('is false when only some fields are present', () {
      const config = AIProviderConfig(
        providerType: AIProviderType.customOpenAI,
        baseUrl: 'https://api.deepseek.com',
        apiKey: 'sk-test',
      );
      expect(config.isCustomOpenAIConfigured, isFalse);
    });

    test('is true when baseUrl, apiKey, and model are all non-empty', () {
      const config = AIProviderConfig(
        providerType: AIProviderType.customOpenAI,
        baseUrl: 'https://api.deepseek.com',
        apiKey: 'sk-test',
        model: 'deepseek-chat',
      );
      expect(config.isCustomOpenAIConfigured, isTrue);
    });
  });

  group('AIProviderConfig.copyWith', () {
    test(
        'preserves fields not overridden, including after switching provider type',
        () {
      const config = AIProviderConfig(
        providerType: AIProviderType.customOpenAI,
        baseUrl: 'https://api.deepseek.com',
        apiKey: 'sk-test',
        model: 'deepseek-chat',
      );

      final switched = config.copyWith(providerType: AIProviderType.gemini);
      expect(switched.providerType, AIProviderType.gemini);
      expect(switched.baseUrl, 'https://api.deepseek.com');
      expect(switched.apiKey, 'sk-test');
      expect(switched.model, 'deepseek-chat');
    });
  });
}
