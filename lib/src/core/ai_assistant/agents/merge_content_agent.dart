import 'package:obsi/src/core/ai_assistant/agents/agent.dart';
import 'package:openai_dart/openai_dart.dart';

class MergeContentAgent implements Agent {
  final String content1;
  final String content2;

  MergeContentAgent(this.content1, this.content2);

  @override
  Future<String> run() async {
    final client = OpenAIClient(apiKey: "zzz");
    final res = await client.createChatCompletion(
      request: CreateChatCompletionRequest(
        model: const ChatCompletionModel.modelId('gpt-4'),
        temperature: 0.2,
        messages: [
          ChatCompletionMessage.system(
            content:
                'You are a helpful assistant that merges the content of two files. Returned result should not contain any information except the merged content.',
          ),
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string(
              'Merge the following files avoiding conent duplication:\n\nFile 1 content:\n$content1\n\nFile 2 content:\n$content2',
            ),
          ),
        ],
      ),
    );

    return res.choices.first.message.content!;
  }
}
