sealed class ChatCompletionMessage {
  const ChatCompletionMessage();

  factory ChatCompletionMessage.system({required String content}) {
    return ChatCompletionSystemMessage(content: content);
  }

  factory ChatCompletionMessage.user(
      {required ChatCompletionUserMessageContent content}) {
    return ChatCompletionUserMessage(content: content);
  }

  factory ChatCompletionMessage.assistant({required String content}) {
    return ChatCompletionAssistantMessage(content: content);
  }
}

class ChatCompletionSystemMessage extends ChatCompletionMessage {
  final String content;

  const ChatCompletionSystemMessage({required this.content});

  @override
  String toString() => content;
}

class ChatCompletionUserMessage extends ChatCompletionMessage {
  final ChatCompletionUserMessageContent content;

  const ChatCompletionUserMessage({required this.content});
}

class ChatCompletionAssistantMessage extends ChatCompletionMessage {
  final String content;

  const ChatCompletionAssistantMessage({required this.content});

  @override
  String toString() => content;
}

sealed class ChatCompletionUserMessageContent {
  const ChatCompletionUserMessageContent();

  factory ChatCompletionUserMessageContent.string(String text) {
    return ChatCompletionUserMessageContentString(text);
  }

  dynamic get value;
}

class ChatCompletionUserMessageContentString
    extends ChatCompletionUserMessageContent {
  final String text;

  const ChatCompletionUserMessageContentString(this.text);

  @override
  String get value => text;

  @override
  String toString() => text;
}

enum ChatCompletionMessageRole {
  system,
  user,
  assistant;

  String get name {
    switch (this) {
      case ChatCompletionMessageRole.system:
        return 'system';
      case ChatCompletionMessageRole.user:
        return 'user';
      case ChatCompletionMessageRole.assistant:
        return 'assistant';
    }
  }
}
