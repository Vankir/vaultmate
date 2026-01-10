import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:obsi/src/core/tasks/task.dart';
import 'package:obsi/src/core/tasks/task_parser.dart';
import 'package:obsi/src/core/tasks/task_source.dart';
import 'package:obsi/src/core/ai_assistant/chat_completion_message.dart';
import 'package:obsi/src/core/ai_assistant/tools_registry.dart';

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
  final toolsRegistry;

  AIAssistant(this.apiKey, this.toolsRegistry);
  // factory AIAssistant.getInstance(String apiKey, ToolsRegistry toolsRegistry) {
  //   return ChatGptAssistant(apiKey, toolsRegistry);
  // }

  Future<String?> chat(List<ChatCompletionMessage> messages,
      String currentDateTime, String vault);

  Future<void> confirmToolAction(int actionId, bool allowed);

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

  @override
  void dispose() {
    _messageController.close();
    super.dispose();
  }
}
