import 'dart:async';
import 'dart:convert';

import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:logger/logger.dart';
import 'package:obsi/src/core/ai_assistant/action.dart';
import 'package:obsi/src/core/ai_assistant/ai_assistant_prompts.dart';
import 'package:obsi/src/core/ai_assistant/extended_generation_config.dart';
import 'package:obsi/src/core/ai_assistant/tools_registry.dart';
import 'package:openai_dart/openai_dart.dart';
import 'ai_assistant.dart';

class GeminiAssistant extends AIAssistant {
  final String modelName = 'gemini-2.0-flash-exp';
  final Map<int, Completer<bool>> _pendingConfirmations = {};
  GeminiAssistant(String apiKey, ToolsRegistry registry)
      : super(apiKey, registry) {
    Gemini.init(apiKey: apiKey);

    //Gemini.instance.listModels().then((models) {
    //   Logger().d("Models: ${models.map((model) => model.name).toList()}");
    //});
  }

  @override
  void reInitialize(String apiKey) {
    this.apiKey = apiKey;
    Gemini.reInitialize(apiKey: apiKey);
  }

  @override
  Future<String?> chat(List<ChatCompletionMessage> messages,
      String currentDateTime, String vault) async {
    List<ChatCompletionMessage> promptWithHistory =
        addSystemPrompt(messages, currentDateTime);

    var chat = promptWithHistory.map(toGeminiMessage).toList();

    var textPart = chat.last.parts!.last as TextPart;
    var userPrompt = textPart.text;
    var prompt = _buildPrompt(
        userPrompt,
        AIAssistantPrompts.assistantMainPrompt,
        "Today is $currentDateTime Vault path (root folder for VaultMate): $vault",
        "");

    var response = await _callChat(chat, prompt);
    // if (response.finalAnswer == null || response.finalAnswer!.isEmpty) {
    emitMessage(AIMessage.reasoning(response.thought));
    // }

    int maxAttempts = 4;
    while (--maxAttempts == 0 ||
        response.finalAnswer == null ||
        response.finalAnswer!.isEmpty ||
        (response.actions != null && response.actions!.isNotEmpty)) {
      if (response.actions != null && response.actions!.isNotEmpty) {
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
        response = await _callChat(chat, continuePrompt);

        emitMessage(AIMessage.reasoning(response.thought));
      }
    }

    emitMessage(AIMessage.text(response.finalAnswer!));
    return response.finalAnswer;
  }

  //Future<ResponseWithAction>
  Future<String> _executeAction(
    Action action,
  ) async {
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

        Logger()
            .i("Calling function $functionName with parameters $parameters");
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

  Future<ResponseWithAction> _callChat(
      List<Content> chat, String prompt) async {
    Logger().i("Prompt: $prompt");
    chat.last = Content(
      parts: [Part.text(prompt)],
      role: ChatCompletionMessageRole.user.name,
    );

    // var models = await Gemini.instance.listModels();
    // Logger().i("Models: ${models.map((model) => model.name).toList()}");

    var res = await Gemini.instance.chat(chat,
        modelName: modelName,
        generationConfig: ExtendedGenerationConfig(
          temperature: 0.3,
          maxOutputTokens: 80192, // Increased to allow longer responses
          responseMimeType: 'application/json',
          responseJsonSchema: {
            "type": "object",
            "properties": {
              "thought": {
                "type": "string",
                "description": "Your reasoning about the user's request"
              },
              "actions": {
                "type": "array",
                "items": {
                  "type": "object",
                  "properties": {
                    "id": {
                      "type": "integer",
                      "description": "Unique action identifier"
                    },
                    "name": {
                      "type": "string",
                      "description": "Name of the tool/function to call"
                    },
                    "parameters": {
                      "type": "array",
                      "items": {"type": "string"},
                      "description": "List of parameters for the function"
                    }
                  },
                  "required": ["id", "name", "parameters"]
                },
                "description": "List of actions to execute"
              },
              "final_answer": {
                "type": "string",
                "description": "Final answer to the user (if no actions needed)"
              }
            },
            "required": ["thought"]
          },
        ));
    var output = res?.output ?? "";
    Logger().i("Raw Gemini Output: $output");
    return _parseResponse(output);
  }

  Content toGeminiMessage(ChatCompletionMessage e) {
    switch (e) {
      case ChatCompletionUserMessage msg:
        // Handle user message content

        var content = msg.content;

        return Content(
            parts: [Part.text(content.value.toString())],
            role: ChatCompletionMessageRole.user.name);

      case ChatCompletionSystemMessage msg:
        // Handle user message content

        return Content(
            parts: [Part.text(msg.content.toString())],
            role: 'user'); //ChatCompletionMessageRole.system.name);

      case ChatCompletionAssistantMessage msg:
        // Handle user message content

        return Content(
            parts: [Part.text(msg.content.toString())],
            role: 'model'); //ChatCompletionMessageRole.assistant.name);

      default:
        Logger().e("Unknown message type: ${e.runtimeType}");
        throw Exception("Unknown message type: ${e.runtimeType}");
    }
  }

  // @override
  // Future<String?> sendPrompt(String userPrompt) async {
  //   Gemini.init(apiKey: apiKey!);
  //   //var models = await Gemini.instance.listModels();
  //   // print("Models: ${models.map((model) => model.name).toList()}");

  //   var prompt = _buildPrompt(
  //       userPrompt,
  //       "You are a helpful assistant. Based on the user_input, you can either respond directly or invoke tools listed in 'tools'. Format your response as JSON according to the 'response_format' schema.\n\n",
  //       "",
  //       "");

  //   var output = await _callGemini(prompt);

  //   var response = _parseResponse(output);
  //   while (response.finalAnswer == null ||
  //       response.finalAnswer!.isEmpty ||
  //       (response.actions != null && response.actions!.isNotEmpty)) {
  //     var toolResult = "";
  //     if (response.actions != null && response.actions!.isNotEmpty) {
  //       for (var action in response.actions!) {
  //         var functionName = action.name;
  //         var parameters = action.parameters;

  //         if (toolsRegistry.functionExists(functionName)) {
  //           var res =
  //               await toolsRegistry.callFunction(functionName, parameters);
  //           toolResult =
  //               "$functionName(${parameters.join(", ")}) produced: $res\n";
  //         }

  //         var continuePrompt = _buildPrompt(
  //             userPrompt,
  //             "Now, based on the observation, give the answer.",
  //             output,
  //             toolResult);
  //         output = await _callGemini(continuePrompt);
  //         response = _parseResponse(output);
  //       }
  //     }
  //   }

  //   return response.finalAnswer;
  // }

  // Future<String> _callGemini(String prompt) async {
  //   Logger().i("Prompt: $prompt");
  //   //print("Prompt: $prompt");
  //   var candidates = await Gemini.instance.prompt(
  //     parts: [Part.text(prompt)],
  //     model: modelName,
  //     generationConfig: GenerationConfig(
  //       temperature: 0.3,
  //       maxOutputTokens: 1024, // Set a higher token limit
  //     ),
  //   );
  //   Logger().i("Output: ${candidates?.output ?? ""}");
  //   return candidates?.output ?? "";
  // }

  String _buildPrompt(String userInput, String instruction, String inputContext,
      String inputObservation) {
    var infos = toolsRegistry.getFunctionInfos();
    var tools = infos.map((info) => info).toList();
    var context = inputContext.isEmpty ? null : inputContext;
    var observation = inputObservation.isEmpty ? null : inputObservation;

    final promptMap = {
      "context": context,
      "observation": observation,
      "instructions": instruction,
      "tools": tools,
      "user_input": userInput
    };

    return jsonEncode(promptMap);
  }

  ResponseWithAction _parseResponse(String response) {
    try {
      // With responseMimeType: 'application/json', Gemini returns pure JSON
      final json = jsonDecode(response) as Map<String, dynamic>;
      return ResponseWithAction.fromJson(json);
    } catch (e) {
      Logger().e("Failed to parse response: $e\nResponse: $response");

      // Check if response was truncated
      if (e is FormatException && e.message.contains("Unterminated")) {
        throw Exception("Response was truncated (likely exceeded token limit). "
            "Try asking for a shorter response or increase maxOutputTokens.");
      }

      throw Exception("Failed to parse response: $e");
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
    // Validate required field (enforced by JSON schema)
    if (!json.containsKey('thought')) {
      throw Exception("Response missing required 'thought' field.");
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
