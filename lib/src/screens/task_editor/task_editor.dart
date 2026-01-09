import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:obsi/src/core/tasks/markdown_task_markers.dart';
import 'package:obsi/src/core/tasks/reccurent_task.dart';
import 'package:obsi/src/core/utils.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';
import 'package:obsi/src/core/tasks/task.dart';
import 'package:obsi/src/screens/task_editor/cubit/task_editor_cubit.dart';
//import 'package:url_launcher/url_launcher.dart';

class TaskEditor extends StatefulWidget {
  const TaskEditor({Key? key}) : super(key: key);

  @override
  State<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<TaskEditor> {
  TaskPriority _taskPriority = TaskPriority.normal;
  Text _dueDate = const Text("");
  Text _scheduledDate = const Text("");
  Text _scheduledTime = const Text("");
  Text _startDate = const Text("");
  Text _createdDate = const Text("");
  Text _doneDate = const Text("");
  Text _cancelledDate = const Text("");
  TaskStatus _taskStatus = TaskStatus.todo;
  Text _taskSource = const Text("");
  // Fixed width for labels to keep controls aligned
  final double _labelWidth = 160.0;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
      ),
      body: BlocBuilder<TaskEditorCubit, TaskEditorState>(
        builder: (context, state) {
          if (state is TaskEditorInitial) {
            _init(state.task);
            return SafeArea(
              child: Column(children: <Widget>[
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      // Description & Tags
                      _buildSection(
                        context,
                        icon: Icons.description_outlined,
                        title: 'Task',
                        children: [
                          TextFormField(
                            keyboardType: TextInputType.multiline,
                            maxLines: null,
                            initialValue: state.task?.description ?? '',
                            decoration: const InputDecoration(
                              hintText: 'Enter your task here',
                              labelText: 'Task description',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              context
                                  .read<TaskEditorCubit>()
                                  .setDescription(value);
                            },
                          ),
                          if (context.read<TaskEditorCubit>().isNewTask)
                            CheckboxListTile(
                              title: const Text('TaskNote format'),
                              value: context
                                  .read<TaskEditorCubit>()
                                  .taskNoteFormat,
                              onChanged: (value) {
                                if (value != null) {
                                  context
                                      .read<TaskEditorCubit>()
                                      .toggleTaskNoteFormat(value);
                                }
                              },
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                            ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Tags',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildTagCloud(context, state),
                            ],
                          ),
                        ],
                      ),

                      // Planning
                      _buildSection(
                        context,
                        icon: Icons.event_note_outlined,
                        title: 'Planning',
                        children: [
                          _buildLabeledRow(
                            "Priority:",
                            DropdownButton<TaskPriority>(
                              isExpanded: true,
                              items: getEnumList(TaskPriority.values),
                              value: _taskPriority,
                              onChanged: (value) {
                                if (value == null) return;
                                _taskPriority = value;
                                context
                                    .read<TaskEditorCubit>()
                                    .setPriority(value);
                                setState(() {});
                              },
                            ),
                          ),
                          _buildLabeledRow(
                            "${MarkdownTaskMarkers.recurringDateMarker} Recurrence:",
                            _buildRecurrenceControl(context, state),
                          ),
                          _buildLabeledRow(
                            "${MarkdownTaskMarkers.dueDateMarker} Due:",
                            Row(children: [
                              addDateTimePicker(
                                  _dueDate, state.task?.due, context, (date) {
                                context
                                    .read<TaskEditorCubit>()
                                    .setDueDate(date);
                              }),
                              IconButton(
                                  onPressed: () {
                                    context
                                        .read<TaskEditorCubit>()
                                        .setDueDate(null);
                                  },
                                  icon: const Icon(Icons.clear_rounded))
                            ]),
                          ),
                          _buildLabeledRow(
                            "${MarkdownTaskMarkers.scheduledDateMarker} Scheduled:",
                            Row(children: [
                              addDateTimePicker(_scheduledDate,
                                  state.task?.scheduled, context, (date) {
                                context
                                    .read<TaskEditorCubit>()
                                    .setScheduledDate(date);
                              }),
                              IconButton(
                                  onPressed: () {
                                    context
                                        .read<TaskEditorCubit>()
                                        .setScheduledDate(null);
                                  },
                                  icon: const Icon(Icons.clear_rounded))
                            ]),
                          ),
                          _buildLabeledRow(
                            "${MarkdownTaskMarkers.startDateMarker} Start:",
                            Row(children: [
                              addDateTimePicker(
                                  _startDate, state.task?.start, context,
                                  (date) {
                                context
                                    .read<TaskEditorCubit>()
                                    .setStartDate(date);
                              }),
                              IconButton(
                                  onPressed: () {
                                    context
                                        .read<TaskEditorCubit>()
                                        .setStartDate(null);
                                  },
                                  icon: const Icon(Icons.clear_rounded))
                            ]),
                          ),
                        ],
                      ),

                      // Notifications
                      _buildSection(
                        context,
                        icon: Icons.notifications_outlined,
                        title: 'Notifications',
                        children: [
                          _buildLabeledRow(
                            "Scheduled notification:",
                            Row(children: [
                              addDateTimePicker(
                                _scheduledTime,
                                state.task == null || !state.task!.scheduledTime
                                    ? DateTime.now()
                                    : state.task?.scheduled,
                                context,
                                (date) {
                                  context
                                      .read<TaskEditorCubit>()
                                      .setScheduledNotificationDateTime(date);
                                },
                                timePicker: true,
                              ),
                              IconButton(
                                  onPressed: () {
                                    context
                                        .read<TaskEditorCubit>()
                                        .setScheduledNotificationDateTime(null);
                                  },
                                  icon: const Icon(Icons.clear_rounded))
                            ]),
                          ),
                        ],
                      ),

                      // Status & metadata
                      _buildSection(
                        context,
                        icon: Icons.info_outline,
                        title: 'Status & metadata',
                        children: [
                          _buildLabeledRow(
                            "Status:",
                            DropdownButton<TaskStatus>(
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem<TaskStatus>(
                                    value: TaskStatus.todo,
                                    child: Text('todo')),
                                DropdownMenuItem<TaskStatus>(
                                    value: TaskStatus.done,
                                    child: Text('done')),
                              ],
                              value: _taskStatus,
                              onChanged: (value) {
                                if (value == null) return;
                                _taskStatus = value;
                                context
                                    .read<TaskEditorCubit>()
                                    .setStatus(value);
                                setState(() {});
                              },
                            ),
                          ),
                          _buildLabeledRow(
                            "${MarkdownTaskMarkers.createdDateMarker} Created:",
                            Row(children: [
                              addDateTimePicker(
                                  _createdDate, state.task?.created, context,
                                  (date) {
                                context
                                    .read<TaskEditorCubit>()
                                    .setCreatedDate(date);
                              }),
                              IconButton(
                                  onPressed: () {
                                    context
                                        .read<TaskEditorCubit>()
                                        .setCreatedDate(null);
                                  },
                                  icon: const Icon(Icons.clear_rounded))
                            ]),
                          ),
                          _buildLabeledRow(
                            "${MarkdownTaskMarkers.doneDateMarker} Done:",
                            Row(children: [
                              addDateTimePicker(
                                  _doneDate, state.task?.done, context, (date) {
                                context
                                    .read<TaskEditorCubit>()
                                    .setDoneDate(date);
                              }),
                              IconButton(
                                  onPressed: () {
                                    context
                                        .read<TaskEditorCubit>()
                                        .setDoneDate(null);
                                  },
                                  icon: const Icon(Icons.clear_rounded))
                            ]),
                          ),
                          _buildLabeledRow(
                            "${MarkdownTaskMarkers.cancelledDateMarker} Cancelled:",
                            Row(children: [
                              addDateTimePicker(_cancelledDate,
                                  state.task?.cancelled, context, (date) {
                                context
                                    .read<TaskEditorCubit>()
                                    .setCancelledDate(date);
                              }),
                              IconButton(
                                  onPressed: () {
                                    context
                                        .read<TaskEditorCubit>()
                                        .setCancelledDate(null);
                                  },
                                  icon: const Icon(Icons.clear_rounded))
                            ]),
                          ),
                        ],
                      ),

                      // Source link
                      Card(
                        elevation: 0,
                        color: Colors.transparent,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 4),
                          child: GestureDetector(
                              onTap: () {
                                context
                                    .read<TaskEditorCubit>()
                                    .launchObsidian(context);
                              },
                              child: Row(
                                children: [
                                  const Icon(Icons.open_in_new, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _initLink(state.task),
                                      style: const TextStyle(
                                        color: Colors.blue,
                                        fontSize: 14,
                                        decoration: TextDecoration.underline,
                                      ),
                                      maxLines: null,
                                      overflow: TextOverflow.visible,
                                    ),
                                  ),
                                ],
                              )),
                        ),
                      ),
                    ],
                  ),
                ),
                // Bottom save button with optional file chooser checkbox
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      children: [
                        if (context.read<TaskEditorCubit>().isNewTask &&
                            !context.read<TaskEditorCubit>().taskNoteFormat)
                          Expanded(
                            flex: 1,
                            child: CheckboxListTile(
                              title: const Text('Choose file'),
                              value: context
                                  .read<TaskEditorCubit>()
                                  .chooseFileEnabled,
                              onChanged: (value) {
                                if (value != null) {
                                  context
                                      .read<TaskEditorCubit>()
                                      .toggleChooseFile(value);
                                }
                              },
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        Expanded(
                          flex: 1,
                          child: SizedBox(
                            height: 40,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.save_outlined, size: 18),
                              label: const Text('Save',
                                  style: TextStyle(fontSize: 14)),
                              onPressed: () {
                                context
                                    .read<TaskEditorCubit>()
                                    .saveTask(context);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ]),
            );
          }

          return Container();
        },
      ),
    );
  }

  List<DropdownMenuItem<T>> getEnumList<T extends Enum>(List<T> values) {
    return values
        .map((e) => DropdownMenuItem<T>(
              value: e,
              child: Text(e.toString().split(".")[1]),
            ))
        .toList();
  }

  void _init(Task? task) {
    _taskPriority = task?.priority ?? TaskPriority.normal;
    _dueDate = Text(_initDate(task?.due));
    _scheduledDate = Text(_initDate(task?.scheduled));
    _scheduledTime = Text(_initTime(task?.scheduled, task?.scheduledTime));
    _startDate = Text(_initDate(task?.start));
    _createdDate = Text(_initDate(task?.created));
    _doneDate = Text(_initDate(task?.done));
    _cancelledDate = Text(_initDate(task?.cancelled));
    _taskStatus = task?.status ?? TaskStatus.todo;
    _taskSource = Text(task?.taskSource?.fileName ?? "");
  }

  String _initDate(DateTime? date) {
    String dateTemplate = SettingsController.getInstance().dateTemplate;
    String formatedDate = dateTemplate;
    if (date != null) {
      formatedDate = DateFormat(dateTemplate).format(date);
    }
    return formatedDate;
  }

  String _initTime(DateTime? dateTime, bool? scheduledTime) {
    String timeTemplate = "HH:mm";
    String formatedTime = timeTemplate;
    if (dateTime != null && scheduledTime != null && scheduledTime == true) {
      formatedTime = DateFormat(timeTemplate).format(dateTime);
    }
    return formatedTime;
  }

  String _initLink(Task? task) {
    if (task != null && task.taskSource != null) {
      return _basename(task.taskSource!.fileName);
    }

    return "";
  }

  // Extracts the last path segment to display only the file name
  String _basename(String path) {
    if (path.isEmpty) return path;
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/');
    return parts.isNotEmpty ? parts.last : path;
  }

  /// Builds the tag cloud widget showing all available tags with highlighting for selected ones
  Widget _buildTagCloud(BuildContext context, TaskEditorState state) {
    final cubit = context.read<TaskEditorCubit>();
    final allTags = cubit.getAllTags();
    final currentTaskTags = cubit.getCurrentTaskTags();

    if (allTags.isEmpty) {
      return const Text(
        'No tags available',
        style: TextStyle(color: Colors.grey),
      );
    }

    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      children: allTags.map((tag) {
        final isSelected = currentTaskTags.contains(tag);
        return GestureDetector(
          onTap: () {
            cubit.toggleTag(tag);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
                width: 1,
              ),
            ),
            child: Text(
              '#$tag',
              style: TextStyle(
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLabeledRow(String label, Widget control) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: _labelWidth,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(child: control),
      ],
    );
  }

  Widget _buildRecurrenceControl(BuildContext context, TaskEditorState state) {
    final options = RecurrentTask.options;

    final task = (state as TaskEditorInitial).task;
    final currentRule = task?.recurrenceRule;
    if (currentRule != null &&
        currentRule.isNotEmpty &&
        !options.contains(currentRule)) {
      options.insert(0, currentRule);
    }

    final dropdownValue =
        (currentRule == null || currentRule.isEmpty) ? 'None' : currentRule;

    return Row(children: [
      Expanded(
        child: DropdownButton<String>(
          isExpanded: true,
          items: options
              .map((o) => DropdownMenuItem<String>(value: o, child: Text(o)))
              .toList(),
          value: dropdownValue,
          onChanged: (val) {
            if (val == null) return;
            context
                .read<TaskEditorCubit>()
                .setRecurrenceRule(val == 'None' ? null : val);
          },
        ),
      ),
    ]);
  }

  // Section card with header and consistent spacing
  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children
                .map((w) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: w,
                    ))
                .toList(),
          ],
        ),
      ),
    );
  }
}
