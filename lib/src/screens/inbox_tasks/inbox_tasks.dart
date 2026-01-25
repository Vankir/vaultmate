import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:obsi/src/core/tasks/task_manager.dart';
import 'package:obsi/src/screens/inbox_tasks/calendar_view.dart';
import 'package:obsi/src/screens/inbox_tasks/file_view.dart';
import 'package:obsi/src/screens/inbox_tasks/main_messages.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';
import 'package:obsi/src/core/tasks/task.dart';
import 'package:obsi/src/screens/settings/settings_service.dart';
import 'package:obsi/src/screens/subscription/subscription_screen.dart';
import 'package:obsi/main_navigator.dart';
import 'package:obsi/src/screens/task_editor/cubit/task_editor_cubit.dart';
import 'package:obsi/src/screens/task_editor/task_editor.dart';
import 'package:obsi/src/widgets/task_card.dart';
import 'package:obsi/src/screens/inbox_tasks/cubit/inbox_tasks_cubit.dart';
import 'package:path/path.dart' as p;

class InboxTasks extends StatelessWidget with WidgetsBindingObserver {
  final InboxTasksCubit _inboxTaskCubit;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  InboxTasks(this._inboxTaskCubit, {super.key}) {
    // there are two instances of InboxTasks but we don't need to refresh tasks two times so only one instance is subscribed
    if (_inboxTaskCubit.today) {
      WidgetsBinding.instance.addObserver(this);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _inboxTaskCubit.refreshTasks();
    }
  }

  @override
  Widget build(BuildContext context) {
    _inboxTaskCubit.updateSearchQuery(_searchController.text);
    // if (_inboxTaskCubit.today) {
    //   WidgetsBinding.instance.addPostFrameCallback((_) {
    //     MainMessages.showDialogIfNeeded(context);
    //   });
    // }
    return Scaffold(
        appBar: _showAppBar(context),
        floatingActionButton: _showActionButton(context),
        body: BlocBuilder<InboxTasksCubit, InboxTasksState>(
            bloc: _inboxTaskCubit,
            builder: (context, state) {
              if (state is InboxTasksList) {
                return _showListView(
                    context, state.tasks, _inboxTaskCubit.searchQuery);
              }

              if (state is InboxTasksLoading) {
                return RefreshIndicator(
                  onRefresh: () async {
                    _inboxTaskCubit.refreshTasks();
                    await Future.delayed(const Duration(milliseconds: 300));
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height - 100,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            const CircularProgressIndicator(),
                            const SizedBox(height: 20),
                            Text('Loading tasks from \n${state.vault}'),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }

              if (state is InboxTasksMessage) {
                // Show the message to user via SnackBar
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                });
                // Display the tasks along with the message
                return _showListView(
                    context, state.tasks, _inboxTaskCubit.searchQuery);
              }

              return Container();
            }));
  }

  Widget _showListView(
      BuildContext context, List<Task> tasks, String highlightedText) {
    final items = _createViewItems(context, tasks, highlightedText);
    // Add extra space after the last card to avoid FAB overlap
    return RefreshIndicator(
      onRefresh: () async {
        _inboxTaskCubit.refreshTasks();
        // Wait a brief moment for the refresh to start
        await Future.delayed(const Duration(milliseconds: 300));
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        controller: _scrollController,
        children: [
          _buildTagFilterLine(context),
          ...items,
          const SizedBox(height: 80), // Adjust height as needed for FAB
        ],
      ),
    );
  }

  AppBar _showAppBar(BuildContext context) {
    return AppBar(
      title: Align(
          alignment: Alignment.centerLeft,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_inboxTaskCubit.caption),
            BlocBuilder<InboxTasksCubit, InboxTasksState>(
                bloc: _inboxTaskCubit,
                builder: (context, _) {
                  return Text(_inboxTaskCubit.subcaption,
                      style: Theme.of(context).textTheme.bodySmall);
                })
          ])),
      actions: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          BlocBuilder<InboxTasksCubit, InboxTasksState>(
            bloc: _inboxTaskCubit,
            builder: (innerContext, _) {
              return SizedBox(
                width: MediaQuery.of(innerContext).size.width / 3,
                height: kToolbarHeight * 0.5,
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Filter tasks...',
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  onChanged: (query) {
                    _inboxTaskCubit.updateSearchQuery(query);
                  },
                ),
              );
            },
          ),
          // Overdue toggle button
          BlocBuilder<InboxTasksCubit, InboxTasksState>(
            bloc: _inboxTaskCubit,
            builder: (context, _) {
              return IconButton(
                tooltip: _inboxTaskCubit.showOverdueOnly
                    ? "Show all tasks"
                    : "Show overdue only",
                icon: Icon(
                  Icons.warning_amber_rounded,
                  color: _inboxTaskCubit.showOverdueOnly ? Colors.red : null,
                ),
                onPressed: () {
                  _inboxTaskCubit.updateShowOverdueTasksOnly(
                      !_inboxTaskCubit.showOverdueOnly);
                },
              );
            },
          ),
          BlocBuilder<InboxTasksCubit, InboxTasksState>(
              bloc: _inboxTaskCubit,
              builder: (context, _) {
                // Helper function to get next view mode
                ViewMode getNextViewMode(ViewMode current) {
                  switch (current) {
                    case ViewMode.list:
                      return ViewMode.grouped;
                    case ViewMode.grouped:
                      return ViewMode.calendar;
                    case ViewMode.calendar:
                      return ViewMode.list;
                  }
                }

                // Helper function to get appropriate icon for each mode
                IconData getViewModeIcon(ViewMode mode) {
                  switch (mode) {
                    case ViewMode.list:
                      return Icons.list;
                    case ViewMode.grouped:
                      return Icons.folder;
                    case ViewMode.calendar:
                      return Icons.calendar_month;
                  }
                }

                // Helper function to get tooltip text
                String getTooltipText(ViewMode currentMode) {
                  ViewMode nextMode = getNextViewMode(currentMode);
                  switch (nextMode) {
                    case ViewMode.list:
                      return "Switch to list view";
                    case ViewMode.grouped:
                      return "Switch to grouped view";
                    case ViewMode.calendar:
                      return "Switch to calendar view";
                  }
                }

                return IconButton(
                    tooltip: getTooltipText(_inboxTaskCubit.viewMode),
                    onPressed: () {
                      ViewMode nextMode =
                          getNextViewMode(_inboxTaskCubit.viewMode);
                      _inboxTaskCubit.updateViewMode(nextMode);
                    },
                    icon: Icon(getViewModeIcon(_inboxTaskCubit.viewMode)));
              }),

          // BlocBuilder<InboxTasksCubit, InboxTasksState>(
          //     bloc: _inboxTaskCubit,
          //     builder: (context, _) {
          //       return IconButton(
          //           tooltip: "Sort",
          //           onPressed: () {
          //             _inboxTaskCubit.updateSortMode(
          //                 _inboxTaskCubit.sortMode == SortMode.none
          //                     ? SortMode.byCreationDate
          //                     : SortMode.none);
          //           },
          //           icon: Icon(_inboxTaskCubit.sortMode == SortMode.none
          //               ? Icons.swap_vert
          //               : Icons.sort));
          //     }),

          //   DropdownButtonHideUnderline(
          //     child: DropdownButton<String>(
          //       icon: Row(children: [
          //         const Icon(Icons.sort),
          //         const Icon(Icons.more_vert)
          //       ]),
          //       items: [
          //         DropdownMenuItem(
          //           value: 'item1',
          //           child: Text('Item 1'),
          //         ),
          //         DropdownMenuItem(
          //           value: 'item2',
          //           child: Text('Item 2'),
          //         ),
          //       ],
          //       onChanged: (value) {
          //         if (value == 'item1') {
          //           // Handle Item 1 action
          //         } else if (value == 'item2') {
          //           // Handle Item 2 action
          //         }
          //       },
          //     ),
          //   ),
        ])
      ],
    );
  }

  Widget _buildTagFilterLine(BuildContext context) {
    return BlocBuilder<InboxTasksCubit, InboxTasksState>(
      bloc: _inboxTaskCubit,
      builder: (context, state) {
        final availableTags = _inboxTaskCubit.availableTags;
        final selectedTags = _inboxTaskCubit.selectedTags;
        final excludedTags = _inboxTaskCubit.excludedTags;

        // Don't show the tag filter line if there are no tags
        if (availableTags.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 32.0,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: availableTags.length,
                    itemBuilder: (context, index) {
                      final tag = availableTags[index];
                      final isSelected = selectedTags.contains(tag);
                      final isExcluded = excludedTags.contains(tag);

                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: GestureDetector(
                          onTap: () {
                            _inboxTaskCubit.toggleTag(tag);
                          },
                          onLongPress: () {
                            _inboxTaskCubit.toggleExcludeTag(tag);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8.0, vertical: 4.0),
                            decoration: BoxDecoration(
                              color: isExcluded
                                  ? Colors.red.shade100
                                  : isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context)
                                          .colorScheme
                                          .surfaceVariant,
                              borderRadius: BorderRadius.circular(16.0),
                              border: Border.all(
                                color: isExcluded
                                    ? Colors.red.shade400
                                    : isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.outline,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '#$tag',
                              style: TextStyle(
                                color: isExcluded
                                    ? Colors.red.shade700
                                    : isSelected
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onPrimary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                fontSize: 11,
                                fontWeight: isSelected || isExcluded
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (selectedTags.isNotEmpty || excludedTags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: GestureDetector(
                    onTap: () {
                      _inboxTaskCubit.clearTagFilter();
                    },
                    child: Icon(
                      Icons.clear,
                      size: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _showActionButton(BuildContext context) {
    return FloatingActionButton(
      child: const Icon(Icons.add),
      onPressed: () {
        var settings = SettingsController.getInstance();
        var createTasksPath =
            p.join(settings.vaultDirectory!, settings.tasksFile);

        Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BlocProvider(
                  create: (context) => TaskEditorCubit(
                      _inboxTaskCubit.taskManager,
                      task: Task("",
                          created: DateTime.now(),
                          scheduled: _inboxTaskCubit.today == true
                              ? DateTime.now()
                              : null),
                      createTasksPath: createTasksPath),
                  child: const TaskEditor()),
            ));
      },
    );
  }

  List<Card> _createViewItems(
      BuildContext context, List<Task> tasks, String highlightedText) {
    switch (_inboxTaskCubit.viewMode) {
      case ViewMode.calendar:
        return _createCalendarViews(tasks, context, highlightedText);
      case ViewMode.grouped:
        return _createFileViews(tasks, context, highlightedText);
      default:
        return tasks.map((task) {
          return _createTaskCard(context, task, highlightedText);
        }).toList();
    }
  }

  List<Card> _createCalendarViews(
      List<Task> tasks, BuildContext context, String highlightedText) {
    List<Card> calendarViews = [];
    List<TaskCard> calendarTasks = [];

    //sort tasks by scheduled date
    tasks.sort((a, b) {
      if (a.scheduled == null && b.scheduled == null) return 0;
      if (a.scheduled == null) return 1; // nulls go to the end
      if (b.scheduled == null) return -1; // nulls go to
      return a.scheduled!.compareTo(b.scheduled!);
    });

    int i = 0;
    bool hitPremiumLimit = false;
    for (var task in tasks) {
      if (!SettingsController.getInstance().hasActiveSubscription && i > 10) {
        //show card with premium upgrade suggestion and skip the rest tasks
        calendarViews.add(_createPremiumUpgradeCalendarView(
            context, tasks.length - i, highlightedText));
        hitPremiumLimit = true;
        break; // Skip the rest of the tasks
      }

      if ((calendarTasks.isNotEmpty &&
              TaskManager.sameDate(
                  calendarTasks[0].task.scheduled, task.scheduled) &&
              task.scheduled != null) ||
          calendarTasks.isNotEmpty &&
              task.scheduled == null &&
              calendarTasks[0].task.scheduled == null) {
        calendarTasks.add(_createTaskCard(context, task, highlightedText));
      } else {
        if (calendarTasks.isNotEmpty) {
          calendarViews.add(CalendarView(
            List<TaskCard>.from(calendarTasks),
            highlightedText: highlightedText,
          ));
        }
        calendarTasks = [_createTaskCard(context, task, highlightedText)];
      }
      i++;
    }

    // Add the last group only if we didn't hit the premium limit
    if (calendarTasks.isNotEmpty && !hitPremiumLimit) {
      calendarViews.add(CalendarView(
        calendarTasks,
        highlightedText: highlightedText,
      ));
    }

    return calendarViews;
  }

  Card _createPremiumUpgradeCalendarView(
      BuildContext context, int hiddenTasksCount, String highlightedText) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Colors.amber.withOpacity(0.1),
              Colors.orange.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: Colors.amber.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.star,
                  color: Colors.amber,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Upgrade to Premium',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber[700],
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'You have $hiddenTasksCount more ${hiddenTasksCount == 1 ? 'task' : 'tasks'}. Upgrade to Premium to see all your tasks without limits.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.8),
                  ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SubscriptionScreen(
                        settingsController: SettingsController.getInstance(),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.upgrade),
                label: const Text('Upgrade Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<FileView> _createFileViews(
      List<Task> tasks, BuildContext context, String highlightedText) {
    List<FileView> fileViews = [];
    List<TaskCard> fileTasks = [];
    for (var task in tasks) {
      if (fileTasks.isNotEmpty &&
          fileTasks[0].task.taskSource!.fileName == task.taskSource!.fileName) {
        fileTasks.add(_createTaskCard(context, task, highlightedText));
      } else {
        fileTasks = [_createTaskCard(context, task, highlightedText)];
        fileViews.add(FileView(
          fileTasks,
          highlightedText: highlightedText,
          vaultName: SettingsController.getInstance().vaultName!,
        ));
      }
    }

    return fileViews;
  }

  TaskCard _createTaskCard(
      BuildContext context, Task task, String highlightedText) {
    return TaskCard(task, hightlightedText: highlightedText,
        taskDonePressed: (bool? res) {
      if (res != null) {
        _inboxTaskCubit.changeTaskStatus(
            task, res == true ? TaskStatus.done : TaskStatus.todo);
      }
    }, editTaskPressed: () {
      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BlocProvider(
                create: (context) =>
                    TaskEditorCubit(_inboxTaskCubit.taskManager, task: task),
                child: const TaskEditor()),
          ));
    },
        rightButtonPressed: _inboxTaskCubit.today
            ? () => _inboxTaskCubit.removeFromTodayPressed(task)
            : () => _inboxTaskCubit.assignForTodayPressed(
                  task,
                ),
        rightButtonIcon: _inboxTaskCubit.today ? Icons.remove : Icons.add,
        startWorkflowPressed: task.tags.contains("obsi_ai")
            ? () => _startWorkflowPressed(context, task)
            : null);
  }

  Future<void> _startWorkflowPressed(BuildContext context, Task task) async {
    if (context.mounted) {
      // Find the MainNavigator ancestor to switch tabs
      final mainNavigatorState =
          context.findAncestorStateOfType<State<MainNavigator>>();

      if (mainNavigatorState != null) {
        // Call the switchToAIWithMessage method using dynamic to access private state
        (mainNavigatorState as dynamic)
            .switchToAIWithMessage(task.description ?? '');
      }
    }
  }
}
