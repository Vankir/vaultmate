import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:obsi/src/core/ai_assistant/ai_assistant.dart';
import 'package:obsi/src/core/ai_assistant/ai_provider_config.dart';
import 'package:obsi/src/core/ai_assistant/openai_compatible_assistant.dart';
import 'package:obsi/src/core/ai_assistant/tools_registry.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:openai_dart/src/generated/client.dart' show HttpMethod;

import 'openai_compatible_assistant_test.mocks.dart';

@GenerateMocks([OpenAIClient])
void main() {
  late MockOpenAIClient client;
  late ToolsRegistry registry;
  late AIProviderConfig config;

  setUp(() {
    client = MockOpenAIClient();
    registry = ToolsRegistry();
    config = const AIProviderConfig(
      providerType: AIProviderType.customOpenAI,
      apiKey: 'sk-test',
      baseUrl: 'https://api.deepseek.com',
      model: 'deepseek-chat',
    );
  });

  CreateChatCompletionResponse responseWith(Map<String, dynamic> jsonPayload) {
    return CreateChatCompletionResponse(
      id: 'chatcmpl-test',
      object: 'chat.completion',
      created: 0,
      model: 'deepseek-chat',
      choices: [
        ChatCompletionResponseChoice(
          index: 0,
          finishReason: ChatCompletionFinishReason.stop,
          logprobs: null,
          message: ChatCompletionAssistantMessage(
            content: jsonEncode(jsonPayload),
          ),
        ),
      ],
    );
  }

  group('OpenAICompatibleAssistant.chat', () {
    test(
        'sends the configured baseUrl/apiKey/model and returns the final answer',
        () async {
      when(client.createChatCompletion(request: anyNamed('request')))
          .thenAnswer((_) async => responseWith({
                'thought': 'Answering directly',
                'final_answer': 'Hello from DeepSeek',
              }));

      final assistant =
          OpenAICompatibleAssistant(config, registry, client: client);

      final result = await assistant.chat([], '2026-08-23', '/vault');

      expect(result, 'Hello from DeepSeek');
      final captured = verify(
              client.createChatCompletion(request: captureAnyNamed('request')))
          .captured
          .single as CreateChatCompletionRequest;
      expect(
          (captured.model as ChatCompletionModelString).value, 'deepseek-chat');
      expect(captured.maxTokens, isNotNull);
      expect(captured.maxTokens! > 1000, isTrue,
          reason:
              'a low/absent token cap lets a long "thought" truncate the JSON mid-response (regression seen in manual testing)');
    });

    test(
        'surfaces a clear "cut off" message when the response is truncated mid-JSON',
        () async {
      when(client.createChatCompletion(request: anyNamed('request')))
          .thenAnswer((_) async => CreateChatCompletionResponse(
                id: 'chatcmpl-test',
                object: 'chat.completion',
                created: 0,
                model: 'deepseek-chat',
                choices: [
                  ChatCompletionResponseChoice(
                    index: 0,
                    finishReason: ChatCompletionFinishReason.length,
                    logprobs: null,
                    // Simulates a response cut off mid-string, as happens
                    // when a long "thought" exhausts the token budget.
                    message: const ChatCompletionAssistantMessage(
                        content: '{"thought": "a very long reasoning chain'),
                  ),
                ],
              ));

      final assistant =
          OpenAICompatibleAssistant(config, registry, client: client);

      String? errorMessage;
      assistant.messageStream.listen((m) {
        if (m.type == AIMessageType.error) errorMessage = m.error;
      });

      final result = await assistant.chat([], '2026-08-23', '/vault');

      expect(result, isNull);
      await Future<void>.delayed(Duration.zero);
      expect(errorMessage, contains('cut off'));
    });

    test(
        'runs a tool call round trip and returns the final answer after execution',
        () async {
      var called = false;
      registry.registerFunction('get_tasks', 'get_tasks(): returns tasks', () {
        called = true;
        return 'no tasks';
      });

      var callCount = 0;
      when(client.createChatCompletion(request: anyNamed('request')))
          .thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          return responseWith({
            'thought': 'I need the tasks',
            'actions': [
              {'id': 1, 'name': 'get_tasks', 'parameters': []}
            ],
          });
        }
        return responseWith({
          'thought': 'Got the tasks',
          'final_answer': 'You have no tasks',
        });
      });

      final assistant =
          OpenAICompatibleAssistant(config, registry, client: client);
      final result = await assistant.chat([], '2026-08-23', '/vault');

      expect(called, isTrue);
      expect(result, 'You have no tasks');
      verify(client.createChatCompletion(request: anyNamed('request')))
          .called(2);
    });

    test('falls back to plain text when no structured response is returned',
        () async {
      when(client.createChatCompletion(request: anyNamed('request')))
          .thenAnswer((_) async => CreateChatCompletionResponse(
                id: 'chatcmpl-test',
                object: 'chat.completion',
                created: 0,
                model: 'deepseek-chat',
                choices: [
                  ChatCompletionResponseChoice(
                    index: 0,
                    finishReason: ChatCompletionFinishReason.stop,
                    logprobs: null,
                    message: const ChatCompletionAssistantMessage(
                        content: 'not json at all'),
                  ),
                ],
              ));

      final assistant =
          OpenAICompatibleAssistant(config, registry, client: client);

      String? errorMessage;
      assistant.messageStream.listen((m) {
        if (m.type == AIMessageType.error) errorMessage = m.error;
      });

      final result = await assistant.chat([], '2026-08-23', '/vault');

      expect(result, isNull);
      await Future<void>.delayed(Duration.zero);
      expect(errorMessage, contains("couldn't understand"));
    });

    test('surfaces a clear error when the API key is rejected (401)', () async {
      when(client.createChatCompletion(request: anyNamed('request')))
          .thenThrow(OpenAIClientException(
        uri: Uri.parse('https://api.deepseek.com/chat/completions'),
        method: HttpMethod.post,
        message: 'Unsuccessful response',
        code: 401,
        body: '{"error": "invalid key"}',
      ));

      final assistant =
          OpenAICompatibleAssistant(config, registry, client: client);

      String? errorMessage;
      assistant.messageStream.listen((m) {
        if (m.type == AIMessageType.error) errorMessage = m.error;
      });

      final result = await assistant.chat([], '2026-08-23', '/vault');

      expect(result, isNull);
      await Future<void>.delayed(Duration.zero);
      expect(errorMessage, contains('rejected'));
    });

    test(
        'surfaces an unreachable-endpoint error when there is no HTTP status code',
        () async {
      when(client.createChatCompletion(request: anyNamed('request')))
          .thenThrow(OpenAIClientException(
        uri: Uri.parse('https://api.deepseek.com/chat/completions'),
        method: HttpMethod.post,
        message: 'Response error',
        body: 'Connection refused',
      ));

      final assistant =
          OpenAICompatibleAssistant(config, registry, client: client);

      String? errorMessage;
      assistant.messageStream.listen((m) {
        if (m.type == AIMessageType.error) errorMessage = m.error;
      });

      final result = await assistant.chat([], '2026-08-23', '/vault');

      expect(result, isNull);
      await Future<void>.delayed(Duration.zero);
      expect(errorMessage, contains('Could not reach'));
    });

    test(
        'a 429 quota-exceeded response (managed DeepSeek contract) surfaces the reset time',
        () async {
      when(client.createChatCompletion(request: anyNamed('request')))
          .thenThrow(OpenAIClientException(
        uri: Uri.parse('https://proxy.example.com/v1/chat/completions'),
        method: HttpMethod.post,
        message: 'Unsuccessful response',
        code: 429,
        body: jsonEncode({
          'resetAt': '2026-08-24T00:00:00Z',
        }),
      ));

      final assistant = OpenAICompatibleAssistant(
        const AIProviderConfig(providerType: AIProviderType.managedDeepSeek),
        registry,
        client: client,
      );

      String? errorMessage;
      assistant.messageStream.listen((m) {
        if (m.type == AIMessageType.error) errorMessage = m.error;
      });

      final result = await assistant.chat([], '2026-08-23', '/vault');

      expect(result, isNull);
      await Future<void>.delayed(Duration.zero);
      expect(errorMessage, contains('2026-08-24T00:00:00Z'));
      expect(errorMessage, contains('free requests'));
    });

    test(
        'a 429 without a recognizable body still gives a generic rate-limit message',
        () async {
      when(client.createChatCompletion(request: anyNamed('request')))
          .thenThrow(OpenAIClientException(
        uri: Uri.parse('https://api.openai.com/v1/chat/completions'),
        method: HttpMethod.post,
        message: 'Unsuccessful response',
        code: 429,
        body: 'rate limited',
      ));

      final assistant =
          OpenAICompatibleAssistant(config, registry, client: client);

      String? errorMessage;
      assistant.messageStream.listen((m) {
        if (m.type == AIMessageType.error) errorMessage = m.error;
      });

      final result = await assistant.chat([], '2026-08-23', '/vault');

      expect(result, isNull);
      await Future<void>.delayed(Duration.zero);
      expect(errorMessage, contains('rate-limiting'));
    });
  });

  group('AIAssistant.fromConfig presets', () {
    test('gemini preset uses the Google OpenAI-compatible endpoint', () {
      final assistant = AIAssistant.fromConfig(
          const AIProviderConfig(
              providerType: AIProviderType.gemini, apiKey: 'g-key'),
          registry) as OpenAICompatibleAssistant;

      expect(assistant.baseUrl,
          'https://generativelanguage.googleapis.com/v1beta/openai');
      expect(assistant.modelName, 'gemini-3.5-flash');
    });

    test('chatgpt preset uses the client SDK default endpoint', () {
      final assistant = AIAssistant.fromConfig(
          const AIProviderConfig(
              providerType: AIProviderType.chatgpt, apiKey: 'oa-key'),
          registry) as OpenAICompatibleAssistant;

      expect(assistant.baseUrl, isNull);
      expect(assistant.modelName, 'gpt-4');
    });

    test('customOpenAI preset uses the user-supplied endpoint/model', () {
      final assistant =
          AIAssistant.fromConfig(config, registry) as OpenAICompatibleAssistant;

      expect(assistant.baseUrl, 'https://api.deepseek.com');
      expect(assistant.modelName, 'deepseek-chat');
    });

    test('managedDeepSeek preset sends an X-Install-Id header and no user key',
        () {
      final assistant = AIAssistant.fromConfig(
          const AIProviderConfig(
              providerType: AIProviderType.managedDeepSeek,
              installId: 'abc123'),
          registry,
          entitlementProofResolver: () => null) as OpenAICompatibleAssistant;

      expect(assistant.apiKey, isEmpty);
      expect(assistant.extraHeaders['X-Install-Id'], 'abc123');
      expect(
          assistant.extraHeaders.containsKey('X-Entitlement-Proof'), isFalse);
    });

    test(
        'managedDeepSeek preset attaches X-Entitlement-Proof when the resolver returns one',
        () {
      final assistant = AIAssistant.fromConfig(
              const AIProviderConfig(
                  providerType: AIProviderType.managedDeepSeek,
                  installId: 'abc123'),
              registry,
              entitlementProofResolver: () => 'recurring-proof-token')
          as OpenAICompatibleAssistant;

      expect(assistant.extraHeaders['X-Entitlement-Proof'],
          'recurring-proof-token');
    });
  });
}
