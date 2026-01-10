import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:logger/logger.dart';
import 'package:obsi/src/core/ai_assistant/extended_generation_config.dart';
import 'package:obsi/src/core/ai_assistant/tools_registry.dart';
import 'package:obsi/src/core/ai_assistant/chat_completion_message.dart';
import 'ai_assistant.dart';

class GeminiAssistant extends AIAssistant {
  final String modelName = 'gemini-2.0-flash-exp';

  GeminiAssistant(String apiKey, ToolsRegistry registry)
      : super(apiKey, registry) {
    Gemini.init(apiKey: apiKey);
  }

  @override
  void reInitialize(String apiKey) {
    this.apiKey = apiKey;
    Gemini.reInitialize(apiKey: apiKey);
  }

  @override
  Future<ResponseWithAction> callAIModel(
      List<ChatCompletionMessage> messages, String prompt) async {
    Logger().i("Prompt: $prompt");

    var chat = messages.map(_toGeminiMessage).toList();
    chat.last = Content(
      parts: [Part.text(prompt)],
      role: ChatCompletionMessageRole.user.name,
    );

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
    return parseResponse(output);
  }

  Content _toGeminiMessage(ChatCompletionMessage e) {
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
    }
  }
}
