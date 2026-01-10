import 'package:dart_openai/dart_openai.dart';
import 'package:logger/logger.dart';
import 'package:obsi/src/core/ai_assistant/tools_registry.dart';
import 'package:obsi/src/core/ai_assistant/chat_completion_message.dart';
import 'ai_assistant.dart';

class OpenAiAPIAssistant extends AIAssistant {
  String modelName;

  OpenAiAPIAssistant(String apiKey, ToolsRegistry registry,
      {String? modelName, String? baseUrl})
      : modelName = modelName ?? 'gpt-4o',
        super(apiKey, registry) {
    OpenAI.apiKey = apiKey;
    if (baseUrl != null && baseUrl.isNotEmpty) {
      OpenAI.baseUrl = baseUrl;
    }
  }

  @override
  void reInitialize(String apiKey) {
    this.apiKey = apiKey;
    OpenAI.apiKey = apiKey;
  }

  @override
  Future<ResponseWithAction> callAIModel(
      List<ChatCompletionMessage> messages, String prompt) async {
    Logger().i("Prompt: $prompt");

    var openAIMessages = messages.map(_toOpenAIMessage).toList();
    openAIMessages.last = OpenAIChatCompletionChoiceMessageModel(
      role: OpenAIChatMessageRole.user,
      content: [OpenAIChatCompletionChoiceMessageContentItemModel.text(prompt)],
    );

    var response = await OpenAI.instance.chat.create(
      model: modelName,
      messages: openAIMessages,
      temperature: 0.3,
      maxTokens: 16384,
      responseFormat: {
        "type": "json_schema",
        "json_schema": {
          "name": "assistant_response",
          "schema": {
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
                  "required": ["id", "name", "parameters"],
                  "additionalProperties": false
                },
                "description": "List of actions to execute"
              },
              "final_answer": {
                "type": "string",
                "description": "Final answer to the user (if no actions needed)"
              }
            },
            "required": ["thought"],
            "additionalProperties": false
          }
        }
      },
    );

    var output = response.choices.first.message.content?.first.text ?? "";
    Logger().i("Raw OpenAI Output: $output");
    return parseResponse(output);
  }

  OpenAIChatCompletionChoiceMessageModel _toOpenAIMessage(
      ChatCompletionMessage e) {
    switch (e) {
      case ChatCompletionUserMessage msg:
        return OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.user,
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.text(
                msg.content.value.toString())
          ],
        );

      case ChatCompletionSystemMessage msg:
        return OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.system,
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.text(
                msg.content.toString())
          ],
        );

      case ChatCompletionAssistantMessage msg:
        return OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.assistant,
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.text(
                msg.content.toString())
          ],
        );
    }
  }
}
