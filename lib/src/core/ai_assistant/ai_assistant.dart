import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:obsi/src/core/tasks/task.dart';
import 'package:obsi/src/core/tasks/task_parser.dart';
import 'package:obsi/src/core/tasks/task_source.dart';
import 'package:obsi/src/core/ai_assistant/chat_completion_message.dart';
import 'package:obsi/src/core/ai_assistant/action.dart';
import 'package:obsi/src/core/ai_assistant/ai_assistant_prompts.dart';

// Message types for different updates
enum AIMessageType {
  text,
  reasoning,
  error,
  loading,
  streamToken,
  done,
  toolConfirmation
}

class AIMessage {
  final AIMessageType type;
  final dynamic content;
  final String? error;

  AIMessage.text(String content) : this(AIMessageType.text, content);
  AIMessage.reasoning(String content) : this(AIMessageType.reasoning, content);
  AIMessage.error(String error) : this(AIMessageType.error, null, error);
  AIMessage.loading() : this(AIMessageType.loading, null);
  AIMessage.streamToken(String token) : this(AIMessageType.streamToken, token);
  AIMessage.done() : this(AIMessageType.done, null);
  AIMessage.toolConfirmation(Map<String, dynamic> payload)
      : this(AIMessageType.toolConfirmation, payload);

  AIMessage(this.type, this.content, [this.error]);
}

abstract class AIAssistant with ChangeNotifier {
  final _messageController = StreamController<AIMessage>.broadcast();
  Stream<AIMessage> get messageStream => _messageController.stream;

  String? apiKey;
  static const String taskBeginMarker = "<!-task->";
  static const String taskEndMarker = "<!-/tasks->";
  static const String sourceInfoMarker = "💡";
  final dynamic toolsRegistry;
  final Map<int, Completer<bool>> _pendingConfirmations = {};

  AIAssistant(this.apiKey, this.toolsRegistry);

  Future<String?> chat(List<ChatCompletionMessage> messages,
      String currentDateTime, String vault) async {
    List<ChatCompletionMessage> promptWithHistory =
        addSystemPrompt(messages, currentDateTime);

    var userPrompt = _extractUserPrompt(promptWithHistory);
    var prompt = buildPrompt(
        userPrompt,
        AIAssistantPrompts.assistantMainPrompt,
        "Today is $currentDateTime Vault path (root folder for VaultMate): $vault",
        "");

    var response = await callAIModel(promptWithHistory, prompt);
    emitMessage(AIMessage.reasoning(response.thought));

    int maxAttempts = 4;
    while (--maxAttempts == 0 ||
        response.finalAnswer == null ||
        response.finalAnswer!.isEmpty ||
        (response.actions != null && response.actions!.isNotEmpty)) {
      if (response.actions != null && response.actions!.isNotEmpty) {
        var toolResult = "";
        for (var action in response.actions!) {
          toolResult += await executeAction(action);
          toolResult += "\n";
        }

        var continuePrompt = buildPrompt(
            userPrompt,
            "Now, based on the observation, give the answer.",
            response.thought,
            toolResult);
        response = await callAIModel(promptWithHistory, continuePrompt);

        emitMessage(AIMessage.reasoning(response.thought));
      }
    }

    emitMessage(AIMessage.text(response.finalAnswer!));
    return response.finalAnswer;
  }

  String _extractUserPrompt(List<ChatCompletionMessage> messages) {
    for (var i = messages.length - 1; i >= 0; i--) {
      if (messages[i] is ChatCompletionUserMessage) {
        var msg = messages[i] as ChatCompletionUserMessage;
        return msg.content.value.toString();
      }
    }
    return "";
  }

  Future<ResponseWithAction> callAIModel(
      List<ChatCompletionMessage> messages, String prompt);

  Future<void> confirmToolAction(int actionId, bool allowed) async {
    var completer = _pendingConfirmations[actionId];
    if (completer != null && !completer.isCompleted) {
      completer.complete(allowed);
    } else {
      Logger().w('No pending confirmation for actionId $actionId');
    }
  }

  void reInitialize(String apiKey);

  List<ChatCompletionMessage> addSystemPrompt(
      List<ChatCompletionMessage> messages, String? currentDateTime) {
    messages.insert(
        0,
        ChatCompletionMessage.system(
          content: getSystemPrompt(),
        ));

    return messages;
  }

  List<dynamic> analyzeResponse(String? response, dateTemplate) {
    if (response == null) {
      return [];
    }
    Logger().i("Response: $response");
    final taskPattern = RegExp(
      '$taskBeginMarker(.*?)$taskEndMarker',
      dotAll: true,
    );
    final matches = taskPattern.allMatches(response);
    final result = <dynamic>[];
    var lastMatchEnd = 0;

    for (final match in matches) {
      var taskContent = match.group(1)?.trim();
      if (taskContent != null) {
        // Add text before the task
        if (match.start > lastMatchEnd) {
          String text = response.substring(lastMatchEnd, match.start).trim();
          Logger().i('Response string: $text');
          result.add(text);
        }

        // Parse the task
        TaskSource? taskSource = _extractTaskSource(taskContent);
        var task = TaskParser().build(
            taskContent.split(sourceInfoMarker).first.trim(),
            taskSource: taskSource);

        Logger().i("Response task: $task");
        result.add(task);

        lastMatchEnd = match.end;
      }
    }

    // Add remaining text after the last task
    if (lastMatchEnd < response.length) {
      var text = response.substring(lastMatchEnd).trim();
      Logger().i('Response string: $text');
      result.add(text);
    }

    Logger().i("Parsed response: $result");
    return result;
  }

  TaskSource? _extractTaskSource(String taskContent) {
    var taskSourcePattern =
        RegExp('$sourceInfoMarker' + r'(\d+);(.+);(\d+);(\d+)');
    var match = taskSourcePattern.firstMatch(taskContent);
    if (match != null) {
      var fileNumber = int.parse(match.group(1)!);
      var fileName = match.group(2);
      var offset = int.parse(match.group(3)!);
      var length = int.parse(match.group(4)!);
      return fileName == null
          ? null
          : TaskSource(fileNumber, fileName, offset, length);
    }
    return null;
  }

  String getSystemPrompt() {
    var systemPrompt =
        '''You are an AI assistant specializing in creating structured, step-by-step guides to help users achieve their goals efficiently.''';

    Logger().i("System prompt: $systemPrompt");
    return systemPrompt;
  }

  String getContextData(String tasks, String? currentDateTime) {
    var contextData = '''
      Today is $currentDateTime. These are user's tasks in markdown format where
      sign ➕ means task is added,
       📅 - task has due date,
       🛫 - task has start date,
       ⏳ - task has scheduled date,
       ✅ - task is done,
       ❌ - task is cancelled,
       ⏬ - task has lowest priority,
       🔽 - task has low priority ,
       🔼 - task has medium priority,
       ⏫ - task has high priority,
       🔺 - task has highest priority,
       $sourceInfoMarker - task location (file and line)
      Tasks are:
$tasks
      ''';
    Logger().i("Context data: $contextData");
    return contextData;
  }

  String serializedTasks(List<Task> tasks, String dateTemplate) {
    var serializedTask = "";
    serializedTask += tasks.map((task) {
      var str = TaskParser().toTaskString(task, dateTemplate: dateTemplate);
      str +=
          '$sourceInfoMarker${task.taskSource?.fileNumber};${task.taskSource?.fileName};${task.taskSource?.offset};${task.taskSource?.length}';
      return str;
    }).join("\n");
    return serializedTask;
  }

  // Add this to handle different message types
  void emitMessage(AIMessage message) {
    _messageController.add(message);
  }

  Future<String> executeAction(Action action) async {
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

  String buildPrompt(String userInput, String instruction, String inputContext,
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

  ResponseWithAction parseResponse(String response) {
    try {
      final json = jsonDecode(response) as Map<String, dynamic>;
      return ResponseWithAction.fromJson(json);
    } catch (e) {
      Logger().e("Failed to parse response: $e\nResponse: $response");

      if (e is FormatException && e.message.contains("Unterminated")) {
        throw Exception("Response was truncated (likely exceeded token limit). "
            "Try asking for a shorter response or increase maxOutputTokens.");
      }

      throw Exception("Failed to parse response: $e");
    }
  }

  @override
  void dispose() {
    _messageController.close();
    super.dispose();
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
