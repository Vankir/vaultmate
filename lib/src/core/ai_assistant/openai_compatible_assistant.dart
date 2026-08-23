import 'dart:async';
import 'dart:convert';

import 'package:logger/logger.dart';
import 'package:obsi/src/core/ai_assistant/action.dart';
import 'package:obsi/src/core/ai_assistant/ai_assistant_prompts.dart';
import 'package:obsi/src/core/ai_assistant/ai_provider_config.dart';
import 'package:obsi/src/core/ai_assistant/tools_registry.dart';
import 'package:openai_dart/openai_dart.dart';

import 'ai_assistant.dart';

/// Talks to any AI provider that implements the standard OpenAI chat
/// completions API — Gemini (via Google's OpenAI-compatible endpoint),
/// ChatGPT, DeepSeek, a local model, or the app's managed-DeepSeek proxy —
/// through one endpoint/key/model configuration, so no provider needs its own
/// subclass (spec FR-001/FR-002/FR-003/FR-006).
///
/// Uses a JSON tool-calling contract (thought/actions/final_answer) rather
/// than OpenAI's native `tools` parameter, since `ToolsRegistry` only exposes
/// free-text function descriptions, not a per-parameter JSON schema — this
/// keeps task-oriented capabilities consistent across every provider (FR-017).
class OpenAICompatibleAssistant extends AIAssistant {
  final String modelName;
  final String? baseUrl;
  final Map<String, String> extraHeaders;
  final Map<int, Completer<bool>> _pendingConfirmations = {};
  OpenAIClient _client;

  /// [client] is exposed for tests to inject a mock; production code always
  /// uses the default, which talks to [baseUrl] (or the provider SDK's
  /// built-in default when [baseUrl] is null, e.g. for plain ChatGPT).
  OpenAICompatibleAssistant(AIProviderConfig config, ToolsRegistry registry,
      {this.baseUrl,
      String? model,
      this.extraHeaders = const {},
      OpenAIClient? client})
      : modelName = model ?? config.model ?? '',
        _client = client ??
            OpenAIClient(
                apiKey: config.apiKey, baseUrl: baseUrl, headers: extraHeaders),
        super(config.apiKey ?? '', registry);

  @override
  void reInitialize(String apiKey) {
    this.apiKey = apiKey;
    _client =
        OpenAIClient(apiKey: apiKey, baseUrl: baseUrl, headers: extraHeaders);
  }

  @override
  Future<String?> chat(List<ChatCompletionMessage> messages,
      String currentDateTime, String vault) async {
    List<ChatCompletionMessage> promptWithHistory =
        addSystemPrompt(messages, currentDateTime);

    var userPrompt = _extractUserPrompt(promptWithHistory.last);
    var prompt = _buildPrompt(
        userPrompt,
        AIAssistantPrompts.assistantMainPrompt,
        "Today is $currentDateTime Vault path (root folder for Obsi): $vault",
        "");

    ResponseWithAction response;
    try {
      response = await _callChat(prompt);
    } catch (e) {
      _emitError(e);
      return null;
    }

    emitMessage(AIMessage.reasoning(response.thought));

    int maxAttempts = 4;
    while (--maxAttempts > 0 &&
        (response.finalAnswer == null ||
            response.finalAnswer!.isEmpty ||
            (response.actions != null && response.actions!.isNotEmpty))) {
      if (response.actions == null || response.actions!.isEmpty) break;

      var toolResult = "";
      for (var action in response.actions!) {
        toolResult += await _executeAction(action);
        toolResult += "\n";
      }

      var continuePrompt = _buildPrompt(
          userPrompt,
          "Now, based on the observation, give the answer.",
          response.thought,
          toolResult);

      try {
        response = await _callChat(continuePrompt);
      } catch (e) {
        _emitError(e);
        return null;
      }

      emitMessage(AIMessage.reasoning(response.thought));
    }

    var finalAnswer = response.finalAnswer ?? "";
    emitMessage(AIMessage.text(finalAnswer));
    return finalAnswer;
  }

  void _emitError(Object e) {
    Logger().e("Error calling OpenAI-compatible provider: $e");
    emitMessage(AIMessage.error(_describeError(e)));
  }

  /// Classifies an error by HTTP status/shape only — never by "which
  /// provider this is" — so the same logic covers every preset, including
  /// the managed-DeepSeek proxy's 429 quota-exceeded response (FR-013/FR-014).
  String _describeError(Object e) {
    if (e is OpenAIClientException) {
      switch (e.code) {
        case 401:
        case 403:
          return "The configured API key was rejected by the provider. Check the key in AI provider settings.";
        case 429:
          return _describeQuotaExceeded(e.body) ??
              "The provider is rate-limiting requests right now. Please try again shortly.";
        case null:
          return "Could not reach the configured endpoint${baseUrl != null ? ' ($baseUrl)' : ''}. Check your network connection.";
        default:
          return "The AI provider returned an error (HTTP ${e.code}): ${e.message}";
      }
    }
    if (e is FormatException) {
      if (e.message.contains('Unterminated')) {
        return "The response was cut off before it finished (likely hit the token limit). Try asking again, or rephrase to keep the answer shorter.";
      }
      return "The AI provider returned a response this app couldn't understand. Try again, or check the configured model.";
    }
    return "Could not reach the configured endpoint${baseUrl != null ? ' ($baseUrl)' : ''}: $e";
  }

  /// A 429 body may (but need not) carry a `resetAt` field identifying when
  /// a daily allowance resets (see contracts/managed-deepseek-interface.md).
  /// Returns null when the body doesn't have that shape, so callers fall
  /// back to a generic rate-limit message for providers that don't use it.
  String? _describeQuotaExceeded(Object? rawBody) {
    if (rawBody is! String) return null;
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is! Map<String, dynamic>) return null;
      final resetAt = decoded['resetAt'];
      if (resetAt is! String) return null;
      return "You've used all your free requests for today. It resets at $resetAt. "
          "Add your own AI provider key in AI provider settings, or upgrade to premium for unlimited access.";
    } catch (_) {
      return null;
    }
  }

  Future<String> _executeAction(Action action) async {
    var functionName = action.name;
    var parameters = action.parameters;
    var toolResult = "";
    if (toolsRegistry.functionExists(functionName)) {
      var res = "";
      try {
        if (toolsRegistry.requiresConfirmation(functionName)) {
          var completer = Completer<bool>();
          _pendingConfirmations[action.id] = completer;

          emitMessage(AIMessage.toolConfirmation({
            'actionId': action.id,
            'name': functionName,
            'parameters': parameters,
            'description': toolsRegistry.getDescription(functionName),
          }));

          var allowed = await completer.future;
          _pendingConfirmations.remove(action.id);

          if (!allowed) {
            return "$functionName(${parameters.join(", ")}) was declined by user.\n";
          }
        }

        res = await toolsRegistry.callFunction(functionName, parameters);
      } catch (e) {
        Logger().e(
            "Error calling function $functionName with parameters $parameters: $e");
        res = "Error: $e";
      }

      toolResult = "$functionName(${parameters.join(", ")}) produced: $res\n";
    } else {
      toolResult =
          "$functionName(${parameters.join(", ")}) is not registered\n";
    }
    return toolResult;
  }

  @override
  Future<void> confirmToolAction(int actionId, bool allowed) async {
    var completer = _pendingConfirmations[actionId];
    if (completer != null && !completer.isCompleted) {
      completer.complete(allowed);
    } else {
      Logger().w('No pending confirmation for actionId $actionId');
    }
  }

  Future<ResponseWithAction> _callChat(String prompt) async {
    final res = await _client.createChatCompletion(
      request: CreateChatCompletionRequest(
        model: ChatCompletionModel.modelId(modelName),
        temperature: 0.3,
        // Generous, but bounded: without this, some OpenAI-compatible
        // providers apply a low default and truncate the response mid-JSON
        // if "thought" runs long, producing an unparseable partial object.
        maxTokens: 8192,
        responseFormat: const ResponseFormat.jsonObject(),
        messages: [
          ChatCompletionMessage.system(content: _jsonSchemaInstruction),
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string(prompt),
          ),
        ],
      ),
    );

    final content = res.choices.firstOrNull?.message.content ?? "";
    Logger().i("Raw OpenAI-compatible provider output: $content");
    return _parseResponse(content);
  }

  static const String _jsonSchemaInstruction =
      'Respond only with a single JSON object matching this shape: '
      '{"thought": string, "actions": [{"id": integer, "name": string, "parameters": [string]}], '
      '"final_answer": string}. Omit "actions" or leave it empty when no tool call is needed. '
      'Only set "final_answer" once you have the complete answer for the user. '
      'Keep "thought" short — one or two sentences summarizing your reasoning, never a long essay — '
      'so the response always fits within the token limit and the JSON is never cut off.';

  String _extractUserPrompt(ChatCompletionMessage message) {
    return switch (message) {
      ChatCompletionUserMessage msg => msg.content.value.toString(),
      ChatCompletionSystemMessage msg => msg.content.toString(),
      ChatCompletionAssistantMessage msg => msg.content ?? "",
      _ => "",
    };
  }

  String _buildPrompt(String userInput, String instruction, String inputContext,
      String inputObservation) {
    var infos = toolsRegistry.getFunctionInfos();
    var context = inputContext.isEmpty ? null : inputContext;
    var observation = inputObservation.isEmpty ? null : inputObservation;

    final promptMap = {
      "context": context,
      "observation": observation,
      "instructions": instruction,
      "tools": infos,
      "user_input": userInput,
    };

    return jsonEncode(promptMap);
  }

  ResponseWithAction _parseResponse(String response) {
    try {
      final json = jsonDecode(response) as Map<String, dynamic>;
      return ResponseWithAction.fromJson(json);
    } catch (e) {
      Logger().e("Failed to parse response: $e\nResponse: $response");
      throw FormatException("Failed to parse response: $e");
    }
  }
}

class ResponseWithAction {
  final String thought;
  final List<Action>? actions;
  final String? finalAnswer;

  ResponseWithAction({
    required this.thought,
    this.actions,
    this.finalAnswer,
  });

  factory ResponseWithAction.fromJson(Map<String, dynamic> json) {
    if (!json.containsKey('thought')) {
      throw const FormatException("Response missing required 'thought' field.");
    }

    final actions = (json['actions'] as List<dynamic>?)
        ?.map((action) => Action.fromJson(action as Map<String, dynamic>))
        .toList();

    return ResponseWithAction(
      thought: json['thought'] as String,
      actions: actions,
      finalAnswer: json['final_answer'] as String?,
    );
  }
}
