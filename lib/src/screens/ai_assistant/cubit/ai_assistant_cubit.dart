import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:obsi/src/core/ai_assistant/ai_assistant.dart';
import 'package:obsi/src/core/ai_assistant/gemini_assistant.dart';
import 'package:obsi/src/core/ai_assistant/openai_assistant.dart';
import 'package:obsi/src/core/ai_assistant/history_storage.dart';
import 'package:obsi/src/core/ai_assistant/tools/tools.dart';
import 'package:obsi/src/core/ai_assistant/tools_registry.dart';
import 'package:obsi/src/core/tasks/task_manager.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as msg_types;
import 'package:obsi/src/screens/settings/settings_controller.dart';
import 'package:obsi/src/core/ai_assistant/chat_completion_message.dart';
import 'ai_assistant_state.dart';

class AIAssistantCubit extends Cubit<AIAssistantState> {
  StreamSubscription<AIMessage>? _messageSubscription;
  final TaskManager _taskManager;
  HistoryStorage? _historyStorage;
  Tools tools;
  List<String> get _welcomeMessage {
    final settings = SettingsController.getInstance();
    final useOpenAI =
        settings.openaiEndpoint != null && settings.openaiEndpoint!.isNotEmpty;

    return [
      "👋 Welcome to AI Assistant!",
      "",
      useOpenAI
          ? "To get started, please configure OpenAI settings in Settings."
          : "To get started, please send your Gemini API key.",
      "",
      "🔑 Get your API key at:",
      useOpenAI
          ? "https://platform.openai.com/api-keys"
          : "https://aistudio.google.com/app/apikey",
      "",
      "Your API key will be saved locally and securely on your device."
    ];
  }

  AIAssistant? aiAssistant;
  var lastMessages = AIAssistantMessages.init();
  TaskManager get taskManager => _taskManager;

  AIAssistantCubit(TaskManager taskManager)
      : _taskManager = taskManager,
        tools = Tools(taskManager),
        super(AIAssistantMessages.init()) {
    //_historyStorage = HistoryStorage('${_taskManager.vaultPath}/obsi_ai.md');
    _initializeAIAssistant();
    _registerTools();
    _initializeConversation();
  }

  void _initializeConversation() async {
    try {
      AIAssistantMessages? loadedMessages =
          await _historyStorage?.loadConversationHistory();

      if (loadedMessages != null) {
        lastMessages = loadedMessages;
      }

      if (aiAssistant?.apiKey == null || aiAssistant?.apiKey == "") {
        lastMessages.addCustomResponse(_welcomeMessage, "text");
      }
      emit(lastMessages);
    } catch (e) {
      Logger().e("Error initializing conversation: $e");
    }
  }

  void _registerTools() {
    ToolsRegistry.getInstance().registerFunction("get_tasks",
        "get_tasks(): Returns available tasks.", () => tools.getTasksTool());

    ToolsRegistry.getInstance().registerFunction("get_file_list",
        "get_file_list(): Returns list of files.", () => tools.getFileList());

    ToolsRegistry.getInstance().registerFunction(
        "get_file_content",
        "get_file_content(full_file_name): Returns content of the file.",
        (fileName) => tools.getFileContentTool(fileName));

    // ToolsRegistry.getInstance().registerFunction(
    //     "rename_file",
    //     "rename_file(old_full_file_name, new_full_file_name): Rename file. Both parameters should be full file names.",
    //     (oldFileName, newFileName) =>
    //         tools.renameFileTool(oldFileName, newFileName));

    ToolsRegistry.getInstance().registerFunction(
        "change_task",
        "change_task(old_task_name, new_task_content): Changes task. old_task_name is beginning of the task description. new_task_content is full task content. ",
        (oldTaskName, newTaskContent) =>
            tools.changeTaskTool(oldTaskName, newTaskContent),
        confirm: true);

    ToolsRegistry.getInstance().registerFunction(
        "write_file_content",
        "write_file_content(full_file_name, content): Writes content to the file.",
        (fileName, content) => tools.writeFileContentTool(fileName, content),
        confirm: true);

    ToolsRegistry.getInstance().registerFunction(
        "find_task",
        "find_task(task_name): Finds a task by beginning of its description.",
        (taskName) => tools.findTask(taskName));

    ToolsRegistry.getInstance().registerFunction(
        "httpPost",
        "httpPost(uri, param): Calls http post method at specified uri and pass param to it.",
        (uri, param) => tools.httpPost(uri, param),
        confirm: true);

    ToolsRegistry.getInstance().registerFunction(
        "httpGet",
        "httpGet(uri): Calls http get method at specified uri.",
        (uri, param) => tools.httpGet(uri),
        confirm: true);
  }

  void _setupMessageListener() {
    _messageSubscription?.cancel();
    _messageSubscription = aiAssistant?.messageStream.listen(_handleMessage);
  }

  Future<void> sendMessage(String message) async {
    lastMessages.typingUser = AIAssistantMessages.aiUser;
    if (aiAssistant?.apiKey == null || aiAssistant?.apiKey == "") {
      SettingsController.getInstance().updateChatGptKey(message);
      _initializeAIAssistant();
      message = "";
      lastMessages.clear();
      lastMessages = AIAssistantMessages(lastMessages);
      lastMessages.addRequest("Hi");
      lastMessages.typingUser = AIAssistantMessages.aiUser;
    } else {
      lastMessages = AIAssistantMessages(lastMessages);
      lastMessages.addRequest(message);
      await _historyStorage?.appendMessageToLog(message, true);
      lastMessages.typingUser = AIAssistantMessages.aiUser;
      emit(lastMessages);
    }

    try {
      await aiAssistant?.chat(
          _aiConversationHistory(),
          DateFormat(_taskManager.dateTemplate).format(DateTime.now()),
          _taskManager.vaultPath);
      lastMessages = AIAssistantMessages(lastMessages);
      // var responseData =
      //     aiAssistant.analyzeResponse(response, taskManager.dateTemplate);
      // lastMessages.addCustomResponse(responseData);
    } on GeminiException catch (e) {
      SettingsController.getInstance().updateChatGptKey("");
      aiAssistant?.apiKey = "";
      lastMessages.clear();
      lastMessages.addCustomResponse(_welcomeMessage, "text");
      lastMessages =
          AIAssistantMessagesWithError(lastMessages, "Invalid API key");
      lastMessages.typingUser = null;
      emit(lastMessages);
    } catch (e) {
      lastMessages.addCustomResponse(
          ["An error occurred while processing your request: $e."], "error");
      Logger().e("Error in AI Assistant: $e");
      lastMessages.typingUser = null;
      emit(lastMessages);
    }
  }

//This method converts chat history in ChatGPT conversation history to provide context of the conversation.
  List<ChatCompletionMessage> _aiConversationHistory() {
    return lastMessages.messages.reversed.map<ChatCompletionMessage>((el) {
      if (el is msg_types.TextMessage) {
        return el.author.id == AIAssistantMessages.user.id
            ? ChatCompletionMessage.user(
                content: ChatCompletionUserMessageContent.string(el.text))
            : ChatCompletionMessage.assistant(content: el.text);
      } else {
        if (el is msg_types.CustomMessage) {
          var response = el.metadata?['response'];
          if (response is List) {
            return ChatCompletionMessage.assistant(
                content: response.map((e) => e.toString()).join("\n"));
          }
        }
      }

      throw Exception("Invalid parameter");
    }).toList();
  }

  @override
  Future<void> close() {
    _messageSubscription?.cancel();
    return super.close();
  }

  void _initializeAIAssistant() {
    final settings = SettingsController.getInstance();
    final endpoint = settings.openaiEndpoint;
    final modelName = settings.openaiModelName;
    final apiKey = settings.chatGptKey ?? '';

    // Use OpenAI if endpoint is specified, otherwise use Gemini
    if (endpoint != null && endpoint.isNotEmpty) {
      // Use OpenAI
      aiAssistant = OpenAiAPIAssistant(
        apiKey,
        ToolsRegistry.getInstance(),
        modelName: modelName,
        baseUrl: endpoint,
      );
      aiAssistant?.reInitialize(apiKey);
    } else {
      // Use Gemini (default)
      aiAssistant = GeminiAssistant(
        apiKey,
        ToolsRegistry.getInstance(),
        modelName: modelName,
      );
      aiAssistant?.reInitialize(apiKey);
    }

    _setupMessageListener();
  }

  void _handleMessage(AIMessage message) async {
    switch (message.type) {
      case AIMessageType.reasoning:
        lastMessages.typingUser = AIAssistantMessages.aiUser;
        _emitMessage(message.content ?? "", "reasoning");
        break;
      case AIMessageType.toolConfirmation:
        if (lastMessages.alwaysAllowTools) {
          if (message.content is Map<String, dynamic>) {
            final payload = message.content as Map<String, dynamic>;
            final actionId = payload['actionId'] as int?;
            if (actionId != null) {
              await aiAssistant?.confirmToolAction(actionId, true);
            }
          }
        } else {
          lastMessages
              .addCustomResponse([message.content], "tool_confirmation");
          var assistantMessage =
              AIAssistantMessages(AIAssistantMessages(lastMessages));
          assistantMessage.typingUser = null;
          emit(assistantMessage);
        }
        break;
      default:
        _emitMessage(message.content ?? "", "text");
        break;
    }
  }

  void _emitMessage(String message, String responseType) async {
    lastMessages.addCustomResponse([message], responseType);
    var assistantMessage =
        AIAssistantMessages(AIAssistantMessages(lastMessages));
    assistantMessage.typingUser =
        responseType == "reasoning" ? AIAssistantMessages.aiUser : null;
    emit(assistantMessage);
    await _historyStorage?.appendMessageToLog(message, false);
  }

  void setShowReasoning(bool value) {
    lastMessages = AIAssistantMessages(lastMessages);
    lastMessages.showReasoning = value;
    emit(lastMessages);
  }

  void setAlwaysAllowTools(bool value) {
    lastMessages = AIAssistantMessages(lastMessages);
    lastMessages.alwaysAllowTools = value;
    emit(lastMessages);
  }

  Future<void> confirmToolAction(int actionId, bool allowed) async {
    for (var msg in lastMessages.messages) {
      if (msg is msg_types.CustomMessage) {
        var metadata = msg.metadata;
        if (metadata == null) {
          continue;
        }
        var type = metadata['type'];
        if (type != 'tool_confirmation') {
          continue;
        }
        var response = metadata['response'];
        if (response is List && response.isNotEmpty) {
          var payload = response.first;
          if (payload is Map<String, dynamic>) {
            if (payload['actionId'] == actionId) {
              payload['decision'] = allowed ? 'allowed' : 'declined';
              break;
            }
          }
        }
      }
    }

    lastMessages = AIAssistantMessages(lastMessages);
    emit(lastMessages);

    await aiAssistant?.confirmToolAction(actionId, allowed);
  }
}
