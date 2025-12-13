import 'dart:convert';

import 'package:obsi/src/core/ai_assistant/agents/agent.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:tuple/tuple.dart';

class FileConflict {
  final String original;
  final String conflict;

  FileConflict({required this.original, required this.conflict});

  factory FileConflict.fromJson(Map<String, dynamic> json) {
    return FileConflict(original: json['original'], conflict: json['conflict']);
  }
}

class ConflictSearchAgent extends Agent {
  final List<String> _inputFiles;
  var _conflictingFiles = <FileConflict>[];

  ConflictSearchAgent(inputFiles) : _inputFiles = inputFiles;

  @override
  Future<void> run() async {
    final prompt =
        '''
Identify pairs of conflicting files from the following list. A conflict exists when two files have the same name, but one is prefixed with 'conflict'. Return the result as a JSON array of objects, each containing 'original' and 'conflict' fields.

Files:
${_inputFiles.join('\n')}

Example format:
[
  {"original": "2025-03-22.md", "conflict": "conflict2025-03-22.md"},
  {"original": "2025-03-21.md", "conflict": "conflict2025-03-21.md"}
]
''';

    final client = OpenAIClient(apiKey: "zzz");
    final res = await client.createChatCompletion(
      request: CreateChatCompletionRequest(
        model: const ChatCompletionModel.modelId('gpt-4'),
        temperature: 0.2,
        messages: [
          ChatCompletionMessage.system(
            content:
                'You are a helpful assistant that finds conflicts in group of files based on their names. Response should not include anything except requested json',
          ),
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string(prompt),
          ),
        ],
      ),
    );

    final List<dynamic> jsonList = json.decode(
      res.choices.first.message.content!,
    );
    _conflictingFiles = jsonList
        .map((json) => FileConflict.fromJson(json))
        .toList();
  }

  List<FileConflict> get result {
    return _conflictingFiles;
  }
}
