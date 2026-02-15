import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:obsi/src/core/tasks/task.dart';
import 'package:obsi/src/core/tasks/task_manager.dart';
import 'package:obsi/src/screens/ai_assistant/cubit/ai_assistant_cubit.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';
import 'package:obsi/src/screens/task_editor/cubit/task_editor_cubit.dart';
import 'package:obsi/src/screens/task_editor/task_editor.dart';
import 'package:obsi/src/widgets/task_card.dart';
import 'package:path/path.dart' as p;

class ObsiChatBubble extends StatelessWidget {
  final Widget child;
  final types.Message message;
  final TaskManager taskManager;
  final AIAssistantCubit aiAssistantCubit;

  const ObsiChatBubble(
      this.taskManager, this.child, this.message, this.aiAssistantCubit,
      {super.key});

  @override
  Widget build(BuildContext context) {
    types.CustomMessage customMessage = message as types.CustomMessage;
    List<dynamic> response = customMessage.metadata?['response'];
    String? responseType = customMessage.metadata?['type'];
    bool isReasoning = responseType == 'reasoning';
    bool isToolConfirmation = responseType == 'tool_confirmation';
    bool showReasoning = aiAssistantCubit.lastMessages.showReasoning;

    if (!showReasoning && isReasoning) {
      return const SizedBox.shrink();
    }

    if (isToolConfirmation && response.isNotEmpty) {
      final payload = response.first as Map<String, dynamic>;
      final int actionId = payload['actionId'] as int;
      final String name = payload['name'] as String;
      final List<dynamic> paramsDynamic =
          payload['parameters'] as List<dynamic>;
      final List<String> parameters =
          paramsDynamic.map((e) => e.toString()).toList();
      final String? description = payload['description'] as String?;
      final String? decision = payload['decision'] as String?;

      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Confirm tool call',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tool: $name',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (description != null && description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Description: $description',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
              if (parameters.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Parameters: ${parameters.join(", ")}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (decision == null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () =>
                          aiAssistantCubit.confirmToolAction(actionId, false),
                      child: const Text('Decline'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () =>
                          aiAssistantCubit.confirmToolAction(actionId, true),
                      child: const Text('Allow'),
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  decision == 'allowed'
                      ? 'User allowed this action.'
                      : 'User declined this action.',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: isReasoning
          ? BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: response.map((part) {
            if (part is String) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: SelectableText(
                  part,
                  style: TextStyle(
                    fontSize: isReasoning ? 13 : 16,
                    height: 1.5,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              );
            } else if (part is Task) {
              String? createTasksPath;
              if (part.taskSource == null) {
                var settings = SettingsController.getInstance();
                createTasksPath =
                    p.join(settings.vaultDirectory!, settings.tasksFile);
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: TaskCard(
                  part,
                  editTaskPressed: () {
                    _onTaskCardPressed(context, part, createTasksPath);
                  },
                  rightButtonPressed: part.taskSource != null
                      ? null
                      : () {
                          _onTaskCardAddTaskPressed(
                              context, part, createTasksPath);
                        },
                  rightButtonIcon: Icons.add,
                ),
              );
            }
            return const SizedBox.shrink();
          }).toList(),
        ),
      ),
    );
  }

  void _onTaskCardPressed(
      BuildContext context, Task task, String? createTasksPath) {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BlocProvider(
              create: (context) => TaskEditorCubit(taskManager,
                  task: task, createTasksPath: createTasksPath),
              child: const TaskEditor()),
        ));
  }

  Future _onTaskCardAddTaskPressed(
      BuildContext context, Task task, String? createTasksPath) async {
    await taskManager.saveTask(task,
        filePath: createTasksPath,
        dataViewDefaultMarkdownFormat:
            SettingsController.getInstance().dataViewDefaultMarkdownFormat);
  }
}
