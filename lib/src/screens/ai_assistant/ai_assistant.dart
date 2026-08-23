import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:obsi/src/screens/ai_assistant/cubit/ai_assistant_cubit.dart';
import 'package:obsi/src/screens/ai_assistant/cubit/ai_assistant_state.dart';
import 'package:obsi/src/widgets/obsi_chat_bubble.dart';
import 'package:bubble/bubble.dart';

class AIAssistant extends StatelessWidget {
  final AIAssistantCubit _aiAssistantCubit;

  const AIAssistant(this._aiAssistantCubit, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: BlocBuilder<AIAssistantCubit, AIAssistantState>(
            bloc: _aiAssistantCubit,
            builder: (context, state) {
              if (state is AIAssistantMessagesWithError) {
                // Show the message to user via SnackBar
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.error),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                });
              }

              if (state is AIAssistantMessages) {
                return Column(
                  children: [
                    Expanded(
                      child: Chat(
                        bubbleBuilder: (child,
                                {required message,
                                required nextMessageInGroup}) =>
                            _bubbleBuilder(context, child,
                                message: message,
                                nextMessageInGroup: nextMessageInGroup),
                        theme: DefaultChatTheme(
                          backgroundColor:
                              Theme.of(context).scaffoldBackgroundColor,
                          inputBackgroundColor:
                              Theme.of(context).colorScheme.surfaceVariant,
                          inputTextColor:
                              Theme.of(context).colorScheme.onSurface,
                          inputBorderRadius: BorderRadius.circular(24),
                          inputPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          inputMargin: const EdgeInsets.all(8),
                          primaryColor: Theme.of(context).primaryColor,
                          secondaryColor:
                              Theme.of(context).colorScheme.surfaceVariant,
                          userNameTextStyle: TextStyle(
                            color: Theme.of(context).primaryColor,
                          ),
                          inputTextStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 16,
                          ),
                          sendButtonIcon: Icon(
                            Icons.send,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        messages: state.messages,
                        showUserNames: true,
                        onSendPressed: (p0) {
                          _aiAssistantCubit.sendMessage(p0.text);
                        },
                        user: AIAssistantMessages.user,
                        typingIndicatorOptions: TypingIndicatorOptions(
                            typingUsers: state.typingUser != null
                                ? [state.typingUser!]
                                : []),
                        // customMessageBuilder: (p0, {required messageWidth}) {
                        //   return TaskCard(Task(p0.toString()));
                        // },
                      ),
                    ),
                  ],
                );
              } else {
                return Container();
              }
            }));
  }

  Widget _bubbleBuilder(
    BuildContext context,
    Widget child, {
    required message,
    required nextMessageInGroup,
  }) {
    final isUserMessage = AIAssistantMessages.aiUser.id != message.author.id;

    return Bubble(
      padding: const BubbleEdges.all(1),
      radius: Radius.circular(15),
      color: isUserMessage
          ? Theme.of(context).primaryColor
          : Theme.of(context).colorScheme.surfaceVariant,
      margin: nextMessageInGroup
          ? const BubbleEdges.symmetric(horizontal: 6)
          : null,
      nip: nextMessageInGroup
          ? BubbleNip.no
          : AIAssistantMessages.user.id != message.author.id
              ? BubbleNip.leftBottom
              : BubbleNip.rightBottom,
      child: isUserMessage
          ? child
          : ObsiChatBubble(
              _aiAssistantCubit.taskManager,
              child,
              message,
              _aiAssistantCubit,
            ),
    );
  }
}
